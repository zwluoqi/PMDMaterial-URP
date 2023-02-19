/*  
 * MMD Shader for Unity
 *
 * Copyright 2012 Masataka SUMI, Takahiro INOUE
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

#include <HLSLSupport.cginc>
#ifndef MeshPmdMaterialSurface_INCLUDE
#define MeshPmdMaterialSurface_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _Color;
float _Opacity;
float4 _AmbColor;
float4 _SpecularColor;
float _Shininess;
float _Cutoff;

float4 _OutlineColor;
float _OutlineWidth;
float _ReceiveShadowMappingAmount;
float _ReceiveShadowMappingPosOffset;
CBUFFER_END

sampler2D _MainTex;
sampler2D _ToonTex;
sampler2D _SphereAddTex;
sampler2D _SphereMulTex;

struct pmd_input_base {
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 texcoord : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct MMDSurfaceOutput
{
	float3 Albedo;
	float3 NormalWS;
	float3 Emission;
	float3 Gloss;
	float3 brdfDiffuse;
	float3 brdfSpecular;
	float Alpha;
	float fogCoord;
	float4 shadowCoord;
	float3 viewDir ;
};


struct Input
{
	float2 uv_MainTex;
};

struct v2f_surf {
	float4 pos : SV_POSITION;
	float2 uv_MainTex : TEXCOORD0;
	float3 normalWS : TEXCOORD1;
	float3 shlight : TEXCOORD2;
	float3 positionWS               : TEXCOORD3;

};

struct MMDLightingData
{
	float3 giColor;
	float3 mainLightColor;
	float3 additionalLightsColor;
	float3 vertexLightingColor;
	float3 emissionColor;
};


float3 CalculateMMDLightingColor(MMDLightingData lightingData, float3 albedo)
{
	float3 lightingColor = 0;

	if (IsOnlyAOLightingFeatureEnabled())
	{
		return lightingData.giColor; // Contains white + AO
	}

	// if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_GLOBAL_ILLUMINATION))
	// {
	// 	lightingColor += lightingData.giColor;
	// }

	if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_MAIN_LIGHT))
	{
		lightingColor += lightingData.mainLightColor;
	}
	//
	if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_ADDITIONAL_LIGHTS))
	{
		lightingColor += lightingData.additionalLightsColor;
	}
	//
	// if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_VERTEX_LIGHTING))
	// {
	// 	lightingColor += lightingData.vertexLightingColor;
	// }
	//
	lightingColor *= albedo;
	//
	// if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_EMISSION))
	// {
	// 	lightingColor += lightingData.emissionColor;
	// }

	return lightingColor;
}

void InitializeStandardLitSurfaceData(v2f_surf IN,out MMDSurfaceOutput o)
{
	o.NormalWS = IN.normalWS;


	
	// Defaults
	o.Emission = 0.0;
	o.Gloss = 0.0;

	// Diffuse Map
	float2 uv_coord = float2( IN.uv_MainTex.x, IN.uv_MainTex.y );
	float4 tex_color = tex2D( _MainTex, uv_coord );
	// Sphere Map
	//float3 viewNormal = normalize( mul( UNITY_MATRIX_MV, float4(normalize(o.Normal), 0.0) ).xyz );//部分机型上这个不支持
	float3 viewNormal = normalize(TransformWorldToViewDir(o.NormalWS));
	float2 sphereUv = viewNormal.xy * 0.5 + 0.5;
	float4 sphereAdd = tex2D( _SphereAddTex, sphereUv );
	float4 sphereMul = tex2D( _SphereMulTex, sphereUv );
	
	// Output
	o.Albedo  = tex_color.rgb*_Color.rgb; // DiffuseTex   Default:White
	o.Albedo += sphereAdd; // SphereAddTex Default:Black
	o.Albedo *= sphereMul; // SphereMulTex Default:White
	o.Alpha = _Opacity * tex_color.a;//不透明的取值已经来自于color.a了,所以不用再次处理了

	half reflectivity = ReflectivitySpecular(_SpecularColor);
	half oneMinusReflectivity = half(1.0) - reflectivity;
	o.brdfDiffuse = o.Albedo * (half3(1.0, 1.0, 1.0) - _SpecularColor);
	o.brdfSpecular = saturate (_SpecularColor);
	

	o.fogCoord = InitializeInputDataFog(float4(IN.positionWS, 1.0), 0);
	o.shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
	o.viewDir = GetWorldSpaceNormalizeViewDir(IN.positionWS);

}
half3 ShadeGI(MMDSurfaceOutput surfaceData)
{
	// hide 3D feeling by ignoring all detail SH (leaving only the constant SH term)
	// we just want some average envi indirect color only
	half3 averageSH = SampleSH(surfaceData.NormalWS);

	// can prevent result becomes completely black if lightprobe was not baked 
	averageSH = max(0,averageSH);

	// occlusion (maximum 50% darken for indirect to prevent result becomes completely black)
	half indirectOcclusion = lerp(1, 1, 0.5);
	return averageSH;
}

inline half MMDLit_GetToolRefl(half NdotL)
{
	half4 _ToonTone = half4(1.0, 0.5, 0.5, 0.0);//TODO
	return NdotL * _ToonTone.y + _ToonTone.z; // Necesally saturate.
}

inline float3 LightingMMDSpecular (MMDSurfaceOutput surfaceData, Light light,bool isAdditionalLight)
{
	// Specular
	float specularStrength = surfaceData.brdfSpecular;
	float dirDotNormalfloat = saturate( dot(surfaceData.NormalWS, normalize(light.direction + surfaceData.viewDir)) );
	float dirSpecularWeight = pow( dirDotNormalfloat, max(_Shininess,0.01) );
	float3 dirSpecular =  light.color.xyz * dirSpecularWeight*specularStrength;
	return dirSpecular;
}

inline float3 LightingMMDRadiance (MMDSurfaceOutput surfaceData, Light light,bool isAdditionalLight)
{
	// light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight(...) in Lighting.hlsl)
	// Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
	half distanceAttenuation = min(4,light.distanceAttenuation); //clamp to prevent light over bright if point/spot light too close to vertex
    
	
	float4 lightColor = float4(light.color.xyz,1.0);
	half3 N = surfaceData.NormalWS;
	half3 L = light.direction;

	half NoL = dot(N,L);
	

	// N dot L
	// simplest 1 line cel shade, you can always replace this line by your own method!
	half toonRefl = saturate(MMDLit_GetToolRefl(NoL));//[0,1]
	float3 toon =  tex2D(_ToonTex, half2(toonRefl, toonRefl));

	 #if SELFSHADOW_ON
	 // light's shadow map
	 toon *= lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount);
	 #endif
	
	//radiance
	float3 radiance = toon * distanceAttenuation* saturate(lightColor);
	radiance *= isAdditionalLight?0.25f:1;
	
	return radiance;
}

inline float3 LightingMMD (MMDSurfaceOutput surfaceData, Light mainLight,bool isAdditionalLight)
{
	
	float3 radiance  = LightingMMDRadiance(surfaceData,mainLight,false);
	float3 specular = LightingMMDSpecular(surfaceData,mainLight,false);
	float3 brdf = surfaceData.brdfDiffuse;
	brdf += specular;
	return  radiance*brdf;
}

v2f_surf vert_surf (pmd_input_base v)
{
	v2f_surf o;
	VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex);
	o.pos = vertexInput.positionCS;
	o.positionWS  = vertexInput.positionWS;
	float3 worldN = mul((float3x3)unity_ObjectToWorld, v.normal);
	o.normalWS = normalize(worldN);
	o.uv_MainTex = v.texcoord;


	o.shlight = SampleSH(float4(o.normalWS, 1.0));

	return o;
}

float3 ShadeAllLights(v2f_surf IN, MMDSurfaceOutput surfaceData)
{
	MMDLightingData lighting_data = (MMDLightingData)0;

	//==============================================================================================
	// Main light is the brightest directional light.
	// It is shaded outside the light loop and it has a specific set of variables and shading path
	// so we can be as fast as possible in the case when there's only a single directional light
	// You can pass optionally a shadowCoord. If so, shadowAttenuation will be computed.
	// float4 shadowCoord = TransformWorldToShadowCoord(lightingData.positionWS);
	Light mainLight = GetMainLight();
	
	#if _MAIN_LIGHT_SHADOWS || _MAIN_LIGHT_SHADOWS_CASCADE
	float3 shadowTestPosWS = IN.positionWS + mainLight.direction * (_ReceiveShadowMappingPosOffset*0.1);
	// compute the shadow coords in the fragment shader now due to this change
	// https://forum.unity.com/threads/shadow-cascades-weird-since-7-2-0.828453/#post-5516425

	// _ReceiveShadowMappingPosOffset will control the offset the shadow comparsion position, 
	// doing this is usually for hide ugly self shadow for shadow sensitive area like face
	float4 shadowCoord = TransformWorldToShadowCoord(shadowTestPosWS);
	mainLight.shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
	#endif 
	
	lighting_data.mainLightColor = LightingMMD(surfaceData,mainLight,false);
	//==============================================================================================

	//==============================================================================================
	// All additional lights

	float3 additionalLightSumResult = 0;

	#ifdef _ADDITIONAL_LIGHTS
	// Returns the amount of lights affecting the object being renderer.
	// These lights are culled per-object in the forward renderer of URP.
	int additionalLightsCount = GetAdditionalLightsCount();
	for (int i = 0; i < additionalLightsCount; ++i)
	{
		// Similar to GetMainLight(), but it takes a for-loop index. This figures out the
		// per-object light index and samples the light buffer accordingly to initialized the
		// Light struct. If ADDITIONAL_LIGHT_CALCULATE_SHADOWS is defined it will also compute shadows.
		int perObjectLightIndex = GetPerObjectLightIndex(i);
		Light light = GetAdditionalPerObjectLight(perObjectLightIndex, IN.positionWS); // use original positionWS for lighting
		light.shadowAttenuation = AdditionalLightRealtimeShadow(perObjectLightIndex, shadowTestPosWS); // use offseted positionWS for shadow test

		// Different function used to shade additional lights.
		additionalLightSumResult += LightingMMD(surfaceData,light,true);
	}
	
	#endif
	//==============================================================================================
	lighting_data.additionalLightsColor = additionalLightSumResult;

	float3 resultColor = CalculateMMDLightingColor(lighting_data,surfaceData.Alpha);
	return resultColor;
}

float4 frag_fast(v2f_surf IN): COLOR
{
	MMDSurfaceOutput surfaceData;
	
	InitializeStandardLitSurfaceData(IN,surfaceData);
	//return float4(surfaceData.brdfDiffuse,surfaceData.Alpha);
	// Indirect lighting
	//lighting_data.giColor = float4(ShadeGI(surfaceData),1.0);
	#ifdef _UseAlphaClipping
	clip(surfaceData.Alpha - _Cutoff);
	#else
	surfaceData.Alpha=1;
	#endif
	
	float3 resultColor = ShadeAllLights(IN,surfaceData);
	
	resultColor.rgb = MixFog(resultColor.rgb, surfaceData.fogCoord);
	float4 color = float4(resultColor,surfaceData.Alpha);

	return color;
}
#endif
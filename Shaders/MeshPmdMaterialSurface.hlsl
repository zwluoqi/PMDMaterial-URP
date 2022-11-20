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

#ifndef MeshPmdMaterialSurface_INCLUDE
#define MeshPmdMaterialSurface_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

float4 _Color;
float _Opacity;
float4 _AmbColor;
float4 _SpecularColor;
float _Shininess;
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
	float Specular;
	float Alpha;
	float4 Custom;
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


void InitializeStandardLitSurfaceData(v2f_surf IN,out MMDSurfaceOutput o)
{
	o.NormalWS = IN.normalWS;

	
	// Defaults
	o.Albedo = 0.0;
	o.Emission = 0.0;
	o.Gloss = 0.0;
	o.Specular = 0.0;

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
	o.Custom  = tex_color; // DiffuseTex   Default:White
	o.Custom += sphereAdd; // SphereAddTex Default:Black
	o.Custom *= sphereMul; // SphereMulTex Default:White
	o.Custom.a = 1.0;
	o.Alpha = _Opacity * tex_color.a;

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
	return averageSH * indirectOcclusion;
}

inline float4 LightingMMD (MMDSurfaceOutput surfaceData, Light light,bool isAdditionalLight)
{
	// light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight(...) in Lighting.hlsl)
	// Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
	half distanceAttenuation = min(4,light.distanceAttenuation); //clamp to prevent light over bright if point/spot light too close to vertex
    
	
	float4 lightColor = float4(light.color.xyz,1.0);
	// Specular
	float specularStrength = surfaceData.Specular;
	float dirDotNormalfloat = max(0, dot(surfaceData.NormalWS, normalize(light.direction + surfaceData.viewDir)));
	float dirSpecularWeight = pow( dirDotNormalfloat, _Shininess );
	float4 dirSpecular = _SpecularColor * lightColor * dirSpecularWeight;
	
	//ToonMapv
	#ifdef SELFSHADOW_ON
	float lightStrength = light.shadowAttenuation;
    #else
    float lightStrength = dot(light.direction, surfaceData.NormalWS) * 0.5 + 0.5;
    #endif

	float4 toon = tex2D( _ToonTex, float2( specularStrength, lightStrength ) );

	float4 color = saturate( _AmbColor + ( _Color * lightColor ) );
	color *= surfaceData.Custom;
 	color += saturate(dirSpecular);
	color *= toon;

	color *= distanceAttenuation;
	// color *= isAdditionalLight?0.25f:1;
	color.a = surfaceData.Alpha;
	return color;
}


v2f_surf vert_surf (pmd_input_base v)
{
	v2f_surf o;
	VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex);
	o.pos = vertexInput.positionCS;
	o.positionWS  = mul(unity_ObjectToWorld,float4(v.vertex.xyz,1.0f) ).xyz;
	float3 worldN = mul((float3x3)unity_ObjectToWorld, v.normal);
	o.normalWS = worldN;
	o.uv_MainTex = v.texcoord;


	o.shlight = SampleSH(float4(worldN, 1.0));

	return o;
}



float4 frag_fast(v2f_surf IN): COLOR
{
	MMDSurfaceOutput surfaceData;
	
	InitializeStandardLitSurfaceData(IN,surfaceData);


	
	// Indirect lighting
	float4 indirectResult = float4(ShadeGI(surfaceData),1.0);
	
	#ifdef _UseAlphaClipping
	clip(surfaceData.Alpha - _Cutoff);
	#endif

	//==============================================================================================
	// Main light is the brightest directional light.
	// It is shaded outside the light loop and it has a specific set of variables and shading path
	// so we can be as fast as possible in the case when there's only a single directional light
	// You can pass optionally a shadowCoord. If so, shadowAttenuation will be computed.
	// float4 shadowCoord = TransformWorldToShadowCoord(lightingData.positionWS);
	Light mainLight = GetMainLight();
	float3 shadowTestPosWS = IN.positionWS ;//+ mainLight.direction * (_ReceiveShadowMappingPosOffset*0.1);
	float4 shadowCoord = TransformWorldToShadowCoord(shadowTestPosWS);
	mainLight.shadowAttenuation = MainLightRealtimeShadow(shadowCoord); 
	
	float4 mainLightResult  = LightingMMD(surfaceData,mainLight,false);
	//==============================================================================================


	//==============================================================================================
	// All additional lights

	float4 additionalLightSumResult = 0;

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
		additionalLightSumResult += LightingMMD(surfaceData, light,true);
	}
	#endif
	//==============================================================================================

	float4 resultColor = mainLightResult + additionalLightSumResult;
	
	resultColor.rgb = MixFog(resultColor.rgb, surfaceData.fogCoord);

	return resultColor;
}
#endif
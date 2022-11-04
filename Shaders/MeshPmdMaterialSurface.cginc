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

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

float4 _Color;
float _Opacity;
float4 _AmbColor;
float4 _SpecularColor;
float _Shininess;
sampler2D _MainTex;
sampler2D _ToonTex;
sampler2D _SphereAddTex;
sampler2D _SphereMulTex;

struct EditorSurfaceOutput
{
	half3 Albedo;
	half3 Normal;
	half3 Emission;
	half3 Gloss;
	half Specular;
	half Alpha;
	half4 Custom;
};


struct Input
{
	float2 uv_MainTex;
};

struct v2f_surf {
	float4 pos : SV_POSITION;
	float2 uv_MainTex : TEXCOORD0;
	half3 normal : TEXCOORD1;
	half3 vlight : TEXCOORD2;
	half3 viewDir : TEXCOORD3;
	// LIGHTING_COORDS(4,5)
	//    half3 mmd_globalAmbient : TEXCOORD6;
	// #ifdef SPHEREMAP_ON
	// half3 mmd_uvwSphere : TEXCOORD7;
	// #endif
};



inline half4 LightingMMD (EditorSurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
{
	// Specular
	float specularStrength = s.Specular;
	float dirDotNormalHalf = max(0, dot(s.Normal, normalize(lightDir + viewDir)));
	float dirSpecularWeight = pow( dirDotNormalHalf, _Shininess );
	float4 dirSpecular = _SpecularColor * _LightColor0 * dirSpecularWeight;
	// ToonMap
	#ifdef SELFSHADOW_ON
	float lightStrength = atten;
    #else
    float lightStrength = dot(lightDir, s.Normal) * 0.5 + 0.5;
    #endif
	float4 toon = tex2D( _ToonTex, float2( specularStrength, lightStrength ) );
	// Output
	float4 color = saturate( _AmbColor + ( _Color * _LightColor0 ) );
	color *= s.Custom;
 	color += saturate(dirSpecular);
	color *= toon;
	color.a = s.Alpha;
	return color;
}


v2f_surf vert_surf (appdata_base v)
{
	v2f_surf o;
	o.pos = UnityObjectToClipPos(v.vertex);
	float3 worldN = mul((float3x3)unity_ObjectToWorld, SCALED_NORMAL);
	o.normal = worldN;
	o.uv_MainTex = v.texcoord;
	o.viewDir = (half3)WorldSpaceViewDir(v.vertex);

	//gi
	o.vlight = ShadeSH9(float4(worldN, 1.0));

	return o;
}

void BRDF(v2f_surf IN,out EditorSurfaceOutput o)
{
	o.Normal = IN.normal;

	
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
	float3 viewNormal = normalize(UnityObjectToViewPos(normalize(o.Normal)) - UnityObjectToViewPos(float3(0.0,0.0,0.0)));
	float2 sphereUv = viewNormal.xy * 0.5 + 0.5;
	float4 sphereAdd = tex2D( _SphereAddTex, sphereUv );
	float4 sphereMul = tex2D( _SphereMulTex, sphereUv );
	
	// Output
	o.Custom  = tex_color; // DiffuseTex   Default:White
	o.Custom += sphereAdd; // SphereAddTex Default:Black
	o.Custom *= sphereMul; // SphereMulTex Default:White
	o.Custom.a = 1.0;
	o.Alpha = _Opacity * tex_color.a;
}


half4 frag_fast(v2f_surf IN): COLOR
{
	EditorSurfaceOutput brdf;
	half atten = LIGHT_ATTENUATION(IN);
	half shadowAtten = SHADOW_ATTENUATION(IN);
	BRDF(IN,brdf);
	
	#ifdef _UseAlphaClipping
	clip(brdf.Alpha - _Cutoff);
	#endif
	
	half4 c = LightingMMD(brdf,_WorldSpaceLightPos0.xyz,IN.viewDir,atten);
	return c;
}

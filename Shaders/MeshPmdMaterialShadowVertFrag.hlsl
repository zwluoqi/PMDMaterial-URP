// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

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
#ifndef MeshPmdMaterialShadowVertFrag_INCLUDE
#define MeshPmdMaterialShadowVertFrag_INCLUDE
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

struct pmd_input
{
	float4 vertex : POSITION;
	float2 texcoord : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
	float4 pos : SV_POSITION;
	float2 uv  : TEXCOORD0;
};

v2f shadow_vert( pmd_input v )
{
	v2f o;
	VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex);
	o.pos = vertexInput.positionCS;
	o.uv = v.texcoord;
	return o;
}

float4 shadow_frag( v2f i ) : COLOR
{
	
	float4 tex_color = tex2D(_MainTex, i.uv);
	#ifdef _UseAlphaClipping
	clip(tex_color.a * _Opacity - _Cutoff);
	#endif

	return float4(0, 0, 0, tex_color.a * _Opacity);
}
#endif
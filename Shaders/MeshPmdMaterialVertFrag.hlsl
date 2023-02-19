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
#ifndef MeshPmdMaterialVertFrag_INCLUDE
#define MeshPmdMaterialVertFrag_INCLUDE
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
// Required by all Universal Render Pipeline shaders.
// It will include Unity built-in shader variables (except the lighting variables)
// (https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html
// It will also include many utilitary functions. 
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// we will include some utility .hlsl files to help us
#include "NiloOutlineUtil.hlsl"

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

struct pmd_input_base {
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 texcoord : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
	float4 pos : SV_POSITION;
	float2 uv  : TEXCOORD0;
};

float3 TransformPositionWSToOutlinePositionWS(float3 positionWS, float positionVS_Z, float3 normalWS)
{
	//you can replace it to your own method! Here we will write a simple world space method for tutorial reason, it is not the best method!
	float outlineExpandAmount = _OutlineWidth * GetOutlineCameraFovAndDistanceFixMultiplier(positionVS_Z);
	return positionWS + normalWS * outlineExpandAmount; 
}

v2f vert( pmd_input_base v )
{
	v2f output;
	VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex);
	VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(v.normal);
	
	float3 positionWS = vertexInput.positionWS;
	positionWS = TransformPositionWSToOutlinePositionWS(vertexInput.positionWS, vertexInput.positionVS.z, vertexNormalInput.normalWS);

	output.pos = TransformWorldToHClip(positionWS);

	
	
	
	// float4 pos = vertexInput.positionCS;
	// // float4 normal = UnityObjectToClipPos(float4(v.normal, 0.0));
	// float4 normal = mul(UNITY_MATRIX_MVP ,(float4(v.normal, 0.0)));
	//
	// float width = _OutlineWidth / 1024.0; //目コピ調整値(算術根拠無し)
	// float depth_offset = pos.z / 4194304.0; //僅かに奥に移動(floatの仮数部は23bitなので(1<<21)程度で割った値は丸めに入らないが非常に小さな値の筈)
	// o.pos = pos + normal * float4(width, width, 0.0, 0.0) + float4(0.0, 0.0, depth_offset, 0.0);

	return output;
}
float4 frag( v2f i ) : COLOR
{
	return float4( _OutlineColor.rgb, _OutlineColor.a * _Opacity );
}
#endif
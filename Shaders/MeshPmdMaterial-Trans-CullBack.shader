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
Shader "MMD/Transparent/PMDMaterial-CullBack"
{
	Properties
	{
		_Color("拡散色", Color) = (1,1,1,1)
		_Opacity("不透明度", Float) = 1.0
		_SpecularColor("反射色", Color) = (1,1,1)
		_AmbColor("環境色", Color) = (1,1,1)
		_Shininess("反射強度", Float) = 0
		_MainTex("テクスチャ", 2D) = "white" {}
		_ToonTex("トゥーン", 2D) = "white" {}
		_SphereAddTex("スフィア（加算）", 2D) = "black" {}
		_SphereMulTex("スフィア（乗算）", 2D) = "white" {}
	}

	SubShader
	{
		Tags{"RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
		Tags { "Queue" = "Transparent+2" "RenderType" = "Transparent" }

		LOD 200
		
		Pass{
			Name "FORWARD"
			Tags{"LightMode" = "UniversalForward"}


				// Surface Shader
				Cull Back
				ZWrite On
				Blend SrcAlpha OneMinusSrcAlpha
//				AlphaTest Greater 0.25
				HLSLPROGRAM
				#include "LightingPragma.hlsl"

				
				#define _UseAlphaClipping
				#define _Cutoff 0.01
				#pragma vertex vert_surf
				#pragma fragment frag_fast

				
				#include "MeshPmdMaterialSurface.hlsl"
				ENDHLSL
		}
		// ShadowCast Pass
		Pass
		{
			Tags
			{
				"LightMode" = "ShadowCaster"
			}
			Cull Off
			Lighting Off
			//Offset [_ShadowBias], [_ShadowBiasSlope] //使えない様なのでコメントアウト
//			AlphaTest Greater 0.25
			
			HLSLPROGRAM
				#define _UseAlphaClipping
				#define _Cutoff 0.01
			#pragma vertex shadow_vert
			#pragma fragment shadow_frag
			//#include "UnityCG.cginc"
			#include "MeshPmdMaterialShadowVertFrag.hlsl"
			ENDHLSL
		}

	}

	// Other Environment
	Fallback "Transparent/Diffuse"
}

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
Shader "MMD/Transparent/PMDMaterial-with-Outline-CullBack-NoCastShadow"
{
	Properties
	{
		_Color("拡散色", Color) = (1,1,1,1)
		_Opacity("不透明度", Float) = 1.0
		_SpecularColor("反射色", Color) = (1,1,1)
		_AmbColor("環境色", Color) = (1,1,1)
		_Shininess("反射強度", Float) = 0
		_OutlineColor("エッジ色", Color) = (0,0,0,1)
		_OutlineWidth("エッジ幅", Range(0,1)) = 0.2
		_MainTex("テクスチャ", 2D) = "white" {}
		_ToonTex("トゥーン", 2D) = "white" {}
		_SphereAddTex("スフィア（加算）", 2D) = "black" {}
		_SphereMulTex("スフィア（乗算）", 2D) = "white" {}
	}

	SubShader
	{
		// Settings
		// Settings
		Tags{"RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
		Tags { "Queue" = "Geometry+2" "RenderType" = "Transparent" }

		LOD 200
		
		Pass{
			Name "FORWARD"
			Tags{"LightMode" = "UniversalForward"}

				// Surface Shader Pass
				Cull Back
				ZWrite On
				Blend SrcAlpha OneMinusSrcAlpha
				AlphaTest Greater 0.0
				CGPROGRAM
				// #pragma surface surf MMD keepalpha
				
			#pragma vertex vert_surf
			#pragma fragment frag_fast
				#pragma multi_compile SELFSHADOW_OFF SELFSHADOW_ON
				#include "MeshPmdMaterialSurface.cginc"
				ENDCG
		}
		
		// Outline Pass
		Pass
		{
			Name "OUTLINE"

			Cull Front
			Lighting Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			#include "MeshPmdMaterialVertFrag.cginc"
			ENDCG
		}
	
	}

	// Other Environment
	Fallback "Transparent/Diffuse"
}
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
Shader "MMD/Transparent/PMDMaterial"
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
			Cull Front
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
//			AlphaTest Greater 0.0
			CGPROGRAM
			
						#define _UseAlphaClipping
				#define _Cutoff 0.01
			#pragma vertex vert_surf
			#pragma fragment frag_fast
			#pragma multi_compile SELFSHADOW_OFF SELFSHADOW_ON
			#include "MeshPmdMaterialSurface.cginc"
			ENDCG
		}

		Pass{
			Name "FORWARD2"
            Tags 
            {
                // IMPORTANT: don't write this line for any custom pass! else this outline pass will not be rendered by URP!
                //"LightMode" = "UniversalForward" 

                // [Important CPU performance note]
                // If you need to add a custom pass to your shader (outline pass, planar shadow pass, XRay pass when blocked....),
                // (0) Add a new Pass{} to your shader
                // (1) Write "LightMode" = "YourCustomPassTag" inside new Pass's Tags{}
                // (2) Add a new custom RendererFeature(C#) to your renderer,
                // (3) write cmd.DrawRenderers() with ShaderPassName = "YourCustomPassTag"
                // (4) if done correctly, URP will render your new Pass{} for your shader, in a SRP-batcher friendly way (usually in 1 big SRP batch)

                // For tutorial purpose, current everything is just shader files without any C#, so this Outline pass is actually NOT SRP-batcher friendly.
                // If you are working on a project with lots of characters, make sure you use the above method to make Outline pass SRP-batcher friendly!
            }

				// Surface Shader
				Cull Back
				ZWrite On
				Blend SrcAlpha OneMinusSrcAlpha
//				AlphaTest Greater 0.25
				CGPROGRAM
								#define _UseAlphaClipping
				#define _Cutoff 0.01
				#pragma vertex vert_surf
				#pragma fragment frag_fast
				
				// #pragma surface surf MMD keepalpha
				#include "MeshPmdMaterialSurface.cginc"
				ENDCG

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
			
			CGPROGRAM
							#define _UseAlphaClipping
				#define _Cutoff 0.01
			#pragma vertex shadow_vert
			#pragma fragment shadow_frag
			#include "UnityCG.cginc"
			#include "MeshPmdMaterialShadowVertFrag.cginc"
			ENDCG
		}

	}

	// Other Environment
	Fallback "Transparent/Diffuse"
}

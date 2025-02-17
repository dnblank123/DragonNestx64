#include "CalcShadow.fxh"
#include "CalcFog.fxh"
//////////////////////////////////////////////////////////////////////////////////////////////
// World Mat Param
//////////////////////////////////////////////////////////////////////////////////////////////
float4x4 g_WorldViewMat			: WORLDVIEW;
#ifdef BAKE_VELOCITY
float4x4 g_PrevWorldViewProjMat		: PREVWORLDVIEWPROJ;
#endif
shared float4x4 g_ProjMat				: PROJECTION;

//////////////////////////////////////////////////////////////////////////////////////////////
// Shared Param
//////////////////////////////////////////////////////////////////////////////////////////////


//////////////////////////////////////////////////////////////////////////////////////////////
// Global Param
//////////////////////////////////////////////////////////////////////////////////////////////
float4 g_LightAmbient			: LIGHTAMBIENT;

int g_DirLightCount				: DIRLIGHTCOUNT;
float3 g_DirLightDirection[ 5 ] : DIRLIGHTDIRECTION;
float4 g_DirLightDiffuse[ 5 ]	: DIRLIGHTDIFFUSE;
float4 g_DirLightSpecular[ 5 ]	: DIRLIGHTSPECULAR;

#define LIGHTMAP_RESTORE_SCALE		2.0f
#define MATERIAL_AMBIENT			float4( 0.682f, 0.682f, 0.682f, 1.0f )
#define MATERIAL_DIFFUSE			float4( 0.682f, 0.682f, 0.682f, 1.0f )

//////////////////////////////////////////////////////////////////////////////////////////////
// Custom Param
//////////////////////////////////////////////////////////////////////////////////////////////
float4 g_WorldOffset;
float4 g_fTextureDistance;
float4 g_fTextureDistance2;
float g_fTileSize;
float4 g_fPixelSize;
float4 g_fTextureRotate12 = { 1.0f, 0.0f, 1.0f, 0.0f };
float4 g_fTextureRotate34 = { 1.0f, 0.0f, 1.0f, 0.0f };

texture2D g_LayerTex1 : LAYERTEXTURE1
< 
	string UIName = "Layer1 Texture";
>;

sampler2D g_LayerSampler1 = sampler_state
{
	Texture = < g_LayerTex1 >;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};
texture2D g_LayerTex2 : LAYERTEXTURE2
< 
	string UIName = "Layer2 Texture";
>;
sampler2D g_LayerSampler2 = sampler_state
{
	Texture = < g_LayerTex2 >;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};
texture2D g_LayerTex3 : LAYERTEXTURE3
< 
	string UIName = "Layer3 Texture";
>;
sampler2D g_LayerSampler3 = sampler_state
{
	Texture = < g_LayerTex3 >;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};
texture2D g_LayerTex4 : LAYERTEXTURE4
< 
	string UIName = "Layer4 Texture";
>;
sampler2D g_LayerSampler4 = sampler_state
{
	Texture = < g_LayerTex4 >;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};


texture2D g_LayerFarTex1 : LAYERFARTEXTURE1
< 
	string UIName = "Layer1 Far Texture";
>;
sampler2D g_LayerFarSampler1 = sampler_state
{
	Texture = < g_LayerFarTex1 >;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};
texture2D g_LayerFarTex2 : LAYERFARTEXTURE2
< 
	string UIName = "Layer2 Far Texture";
>;
sampler2D g_LayerFarSampler2 = sampler_state
{
	Texture = < g_LayerFarTex2 >;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};
texture2D g_LayerFarTex3 : LAYERFARTEXTURE3
< 
	string UIName = "Layer3 Far Texture";
>;
sampler2D g_LayerFarSampler3 = sampler_state
{
	Texture = < g_LayerFarTex3 >;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};
texture2D g_LayerFarTex4 : LAYERFARTEXTURE4
< 
	string UIName = "Layer4 Far Texture";
>;
sampler2D g_LayerFarSampler4 = sampler_state
{
	Texture = < g_LayerFarTex4 >;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};

float4 g_TerrainBlockSize;
texture2D g_LightMap : LIGHTMAP;
sampler2D g_LightMapSampler = sampler_state
{
	Texture = < g_LightMap >;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Mirror;
	AddressV = Mirror;
};


//////////////////////////////////////////////////////////////////////////////////////////////
// Vertex Buffer Declaration
//////////////////////////////////////////////////////////////////////////////////////////////
struct VertexInputCliff
{
    float3 Position				: POSITION;
    float3 Normal				: NORMAL;
    float2 TexCoord0			: TEXCOORD0;
    float2 TexCoord1			: TEXCOORD1;
    float4 LayerAlpha			: COLOR0;
    float4 CoordAlpha			: COLOR1;
};

struct VertexOutputCliff
{
    float4 Position				: POSITION;
    float3 WorldViewPos			: TEXCOORD0;
    float4 TexCoord0_1			: TEXCOORD1;
    float4 TexCoord2_Fog		: TEXCOORD2;
    float4 LayerAlpha			: TEXCOORD3;
    float4 CoordAlpha			: TEXCOORD4;
    float4 LightMapCoord		: TEXCOORD5;
    float3 ShadowMapCoord		: TEXCOORD6;
    float3 WorldViewNormal		: TEXCOORD7;
};

struct PixelOutput
{
	float4 Color				: COLOR0;
};


//////////////////////////////////////////////////////////////////////////////////////////////
// Start Vertex Shader
//////////////////////////////////////////////////////////////////////////////////////////////
VertexOutputCliff LayeredCliffTerrainVS( VertexInputCliff Input ) 
{
	VertexOutputCliff Output;

	float3 WorldViewPos = mul( float4( Input.Position.xyz, 1.0f ), g_WorldViewMat );
	Output.WorldViewPos = WorldViewPos;
	Output.Position = mul( float4( WorldViewPos, 1.0f ), g_ProjMat );

	float3 WorldViewNormal = mul( Input.Normal, g_WorldViewMat );
	Output.WorldViewNormal = normalize( WorldViewNormal );

	Output.LayerAlpha = Input.LayerAlpha;
	Output.TexCoord0_1.xy = ( Input.Position.xz + g_WorldOffset.xz ) / g_fTileSize;
	Output.TexCoord2_Fog.zw = CalcFogValue( Output.Position.z );

	Output.CoordAlpha = Input.CoordAlpha;
	Output.TexCoord0_1.zw = Input.TexCoord0;
	Output.TexCoord2_Fog.xy = Input.TexCoord1;

	float2 ScreenCoord = Output.Position.xy / Output.Position.w;
	Output.LightMapCoord.zw = ( ScreenCoord + 1.0f ) * 0.5f;
	Output.LightMapCoord.w = 1.0f - Output.LightMapCoord.w;

	Output.LightMapCoord.xy = Input.Position.xz / g_TerrainBlockSize + g_fPixelSize.xy;
	float4 LightSpacePos = mul( float4( Input.Position.xyz, 1.0f ) , g_WorldLightViewProjMat );
	Output.ShadowMapCoord.xy = 0.5f * LightSpacePos.xy / LightSpacePos.w + float2( 0.5f, 0.5f );
	Output.ShadowMapCoord.y = 1.0f - Output.ShadowMapCoord.y;
	Output.ShadowMapCoord.z = dot( float4( Input.Position.xyz, 1.0f ), g_WorldLightViewProjDepth );

	return Output;
}

//////////////////////////////////////////////////////////////////////////////////////////////
// Start Pixel Shader
//////////////////////////////////////////////////////////////////////////////////////////////
float4 CalcCliffTerrain( VertexOutputCliff Input )
{
	float2 vTemp;
	vTemp.x = Input.TexCoord0_1.x * g_fTextureRotate12.x + Input.TexCoord0_1.y * -g_fTextureRotate12.y;
	vTemp.y = Input.TexCoord0_1.x * g_fTextureRotate12.y + Input.TexCoord0_1.y * g_fTextureRotate12.x;
	float4 LayerTex1 = tex2D( g_LayerSampler1, vTemp * g_fTextureDistance.x );
	
	vTemp.x = Input.TexCoord0_1.x * g_fTextureRotate12.z + Input.TexCoord0_1.y * -g_fTextureRotate12.w;
	vTemp.y = Input.TexCoord0_1.x * g_fTextureRotate12.w + Input.TexCoord0_1.y * g_fTextureRotate12.z;
	float4 LayerTex2 = tex2D( g_LayerSampler2, vTemp * g_fTextureDistance.y );

	vTemp.x = Input.TexCoord0_1.x * g_fTextureRotate34.x + Input.TexCoord0_1.y * -g_fTextureRotate34.y;
	vTemp.y = Input.TexCoord0_1.x * g_fTextureRotate34.y + Input.TexCoord0_1.y * g_fTextureRotate34.x;
	float4 LayerTex3 = tex2D( g_LayerSampler3, vTemp * g_fTextureDistance.z );

	vTemp.x = Input.TexCoord0_1.z * g_fTextureRotate34.z + Input.TexCoord0_1.w * -g_fTextureRotate34.w;
	vTemp.y = Input.TexCoord0_1.z * g_fTextureRotate34.w + Input.TexCoord0_1.w * g_fTextureRotate34.z;
	float4 LayerTex41 = tex2D( g_LayerSampler4, vTemp );

	vTemp.x = Input.TexCoord2_Fog.x * g_fTextureRotate34.z + Input.TexCoord2_Fog.y * -g_fTextureRotate34.w;
	vTemp.y = Input.TexCoord2_Fog.x * g_fTextureRotate34.w + Input.TexCoord2_Fog.y * g_fTextureRotate34.z;
	float4 LayerTex42 = tex2D( g_LayerSampler4, vTemp );

	float4 LayerTex4 = lerp( LayerTex42, LayerTex41, Input.CoordAlpha.w );

	float4 Result = lerp( LayerTex1, LayerTex2, Input.LayerAlpha.w );
	Result = lerp( Result, LayerTex3, Input.LayerAlpha.x );
	Result = lerp( Result, LayerTex4, Input.LayerAlpha.y );

	return Result;
}

float4 CalcDetailCliffTerrain( VertexOutputCliff Input )
{
	float4 LayerTex1 = tex2D( g_LayerSampler1, Input.TexCoord0_1.xy * g_fTextureDistance.x );
	LayerTex1 = ( LayerTex1 + tex2D( g_LayerFarSampler1, Input.TexCoord0_1.xy * g_fTextureDistance2.x ) ) * 0.5f;
	float4 LayerTex2 = tex2D( g_LayerSampler2, Input.TexCoord0_1.xy * g_fTextureDistance.y );
	LayerTex2 = ( LayerTex2 + tex2D( g_LayerFarSampler2, Input.TexCoord0_1.xy * g_fTextureDistance2.y ) ) * 0.5f;
	float4 LayerTex3 = tex2D( g_LayerSampler3, Input.TexCoord0_1.xy * g_fTextureDistance.z );
	LayerTex3 = ( LayerTex3 + tex2D( g_LayerFarSampler3, Input.TexCoord0_1.xy * g_fTextureDistance2.z ) ) * 0.5f;
	float4 LayerTex41 = tex2D( g_LayerSampler4, Input.TexCoord0_1.zw );
	float4 LayerTex42 = tex2D( g_LayerSampler4, Input.TexCoord2_Fog.xy );
	float4 LayerTex4 = lerp( LayerTex42, LayerTex41, Input.CoordAlpha.w );
	LayerTex4 = ( LayerTex4 + tex2D( g_LayerFarSampler4, Input.TexCoord0_1.xy * g_fTextureDistance2.w ) ) * 0.5f;
	
	float4 Result = lerp( LayerTex1, LayerTex2, Input.LayerAlpha.w );
	Result = lerp( Result, LayerTex3, Input.LayerAlpha.x );
	Result = lerp( Result, LayerTex4, Input.LayerAlpha.y );
	
	Result.w = 1.0f;
	
	return Result;
}

PixelOutput LayeredCliffTerrainPS( VertexOutputCliff Input )
{
	PixelOutput Output;

	Output.Color = CalcCliffTerrain( Input );
	float fSpecularTexAlpha = 1.0f - Output.Color.w;
	Output.Color.w = 1.0f;

	float4 SpecularLight = float4( 0.0f, 0.0f, 0.0f, 0.0f );
	float3 WorldViewEyeVec = -normalize( Input.WorldViewPos );
	float3 HalfWayVec = normalize( WorldViewEyeVec - g_DirLightDirection[ 0 ] );
	SpecularLight.xyz += g_DirLightSpecular[ 0 ].xyz * pow( max( 0 , dot( Input.WorldViewNormal, HalfWayVec ) ), 10.0f );

	float4 ShadowColor;	
	ShadowColor = tex2D( g_LightMapSampler, Input.LightMapCoord ) * LIGHTMAP_RESTORE_SCALE;

	float3 AmbientColor = g_LightAmbient * MATERIAL_AMBIENT;
	ShadowColor.xyz = CalcTerrainShadow( Input.ShadowMapCoord, AmbientColor, ShadowColor.xyz );

	// 원래는 rgb다 더해서 3으로 나누는 식이 맞는건데, ps2_0으로 돌리려다보니 연산개수가 64개 이하여야한다.
	// 그래서 어쩔 수 없이 red채널값은 계산에서 제외하기로 한다.(노란라이트와 푸른라이트가 붉은 라이트보다 많이 쓰이는거 같아서)
	//float3 fShadowPower = ( ShadowColor.x + ShadowColor.y + ShadowColor.z ) / 3.0f;
	float3 fShadowPower = ( ShadowColor.y + ShadowColor.z ) / 2.0f;
	SpecularLight.xyz = SpecularLight.xyz * fShadowPower * fSpecularTexAlpha;
	Output.Color += SpecularLight;

	Output.Color.xyz *= ShadowColor.xyz;

	float4 FogColor = tex2D( g_FogSkyBoxSampler, Input.LightMapCoord.zw );
	FogColor.xyz = lerp( g_FogColor.xyz, FogColor.xyz, Input.TexCoord2_Fog.w );
	Output.Color.xyz = lerp( FogColor.xyz, Output.Color.xyz, Input.TexCoord2_Fog.z );

#ifdef BAKE_DEPTHMAP
	Output.Depth = float4( Input.DepthValue.x, 0.0f, 0.0f, 0.0f );
#endif
#ifdef BAKE_VELOCITY
	Output.Velocity = float4( Input.Velocity, 0.0f, 1.0f );
#endif

	return Output;
}

PixelOutput LayeredDetailCliffTerrainPS( VertexOutputCliff Input )
{
	PixelOutput Output;

	Output.Color = CalcDetailCliffTerrain( Input );

	float4 ShadowColor;

	ShadowColor = tex2D( g_LightMapSampler, Input.LightMapCoord ) * LIGHTMAP_RESTORE_SCALE;
	float3 AmbientColor = g_LightAmbient * MATERIAL_AMBIENT;
	float3 ShadowValue = CalcTerrainShadow( Input.ShadowMapCoord, AmbientColor, ShadowColor.xyz );
	ShadowColor.xyz *= ShadowValue.xyz;
	Output.Color.xyz *= ShadowColor.xyz;

	float4 FogColor = tex2D( g_FogSkyBoxSampler, Input.LightMapCoord.zw );
	FogColor.xyz = lerp( g_FogColor.xyz, FogColor.xyz, Input.TexCoord2_Fog.w );
	Output.Color.xyz = lerp( FogColor.xyz, Output.Color.xyz, Input.TexCoord2_Fog.z );

	return Output;
}

//////////////////////////////////////////////////////////////////////////////////////////////
// Start Technique
//////////////////////////////////////////////////////////////////////////////////////////////
technique LayeredCliffTerrainTech
{
    pass p0 
    {		
		VertexShader = compile vs_2_0 LayeredCliffTerrainVS();
		PixelShader  = compile ps_2_0 LayeredCliffTerrainPS();
    }
}

technique LayeredDetailCliffTerrainTech
{
    pass p0 
    {		
		VertexShader = compile vs_2_0 LayeredCliffTerrainVS();
		PixelShader  = compile ps_2_0 LayeredDetailCliffTerrainPS();
    }
}


#include "CalcBlendBone.fxh"
#include "CalcFog.fxh"
#include "CalcLight.fxh"
#include "CalcShadow.fxh"
//////////////////////////////////////////////////////////////////////////////////////////////
// World Mat Param
//////////////////////////////////////////////////////////////////////////////////////////////
float4x4 g_WorldViewMat			: WORLDVIEW;
float4x4 g_InvViewMat			: INVVIEW;
#ifdef BAKE_VELOCITY
float4x4 g_PrevWorldViewProjMat		: PREVWORLDVIEWPROJ;
float4x4 g_InvWorldViewPrevWVPMat : INVWORLDVIEWPREVWORLDVIEWPROJ;
#endif

//////////////////////////////////////////////////////////////////////////////////////////////
// Shared Param
//////////////////////////////////////////////////////////////////////////////////////////////
shared float4x4 g_ProjMat				: PROJECTION;
shared float g_fElapsedTime				: TIME;

//////////////////////////////////////////////////////////////////////////////////////////////
// Global Param
//////////////////////////////////////////////////////////////////////////////////////////////
#ifdef _3DSMAX_
float4x4 g_WorldViewProjMat		: WORLDVIEWPROJ;
float4 g_LightDir		: DIRECTION
<
    string UIName = "Light Direction";
	string Object = "TargetLight";
	int RefID = 0;
> = { 0.577f, -0.577f, 0.577f, 0.0f };
float4 g_LightDiffuse : LIGHTCOLOR
<
    int LightRef = 0;
> = { 1.0f, 1.0f, 1.0f, 1.0f };
#endif

//////////////////////////////////////////////////////////////////////////////////////////////
// Custom Param
//////////////////////////////////////////////////////////////////////////////////////////////
#define _USE_DIFFUSE_
#include "MaterialColor.fxh"

texture2D g_EnvTex : ENVTEXTURE
< 
	string UIName = "Environment Texture";
>;
sampler2D g_EnvSampler = sampler_state
{
	texture = < g_EnvTex >;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = None;
};

texture2D g_MaskTex : MASKTEXTURE
< 
	string UIName = "Mask Texture";
>;
sampler2D g_MaskSampler = sampler_state
{
	texture = < g_MaskTex >;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};

float4 g_EmissiveColor[ 5 ]		: EMMISIVECOLOR
<
    string UIName = "EmissiveColor";
>;
float g_EmissivePower : EMISSIVEPOWER
<
    string UIName = "Emissive Power";
> = 1.0f;
float g_EmissivePowerRange : EMISSIVEPOWERRANGE
<
    string UIName = "Emissive Power Range";
> = 0.0f;
float g_EmissiveAniSpeed : EMISSIVEANISPEED
<
    string UIName = "Emissive Ani Speed";
> = 1.0f;


float4 g_SkinColor : SKINCOLOR
<
    string UIName = "Skin Color";
> = { 0.5 , 0.5, 0.5, 1.0 };

float4 g_EyeColor : EYECOLOR
<
    string UIName = "Eye Color";
> = { 1.0, 1.0, 1.0, 1.0 };

float4 g_SkinCoeffA = float4( 1414.7135, 1414.7135, 1414.7135, 1);
float4 g_SkinCoeffB = float4( 1.0, 1.0, 1.0, 1);
float4 g_SkinCoeffC = float4( 4000000, 4000000, 4000000, 1);
float4 g_SkinCoeffD = float4( -1413.7135, -1413.7135, -1413.7135, 1);

//////////////////////////////////////////////////////////////////////////////////////////////
// Vertex Buffer Declaration
//////////////////////////////////////////////////////////////////////////////////////////////
struct VertexInput
{
    float3 Position				: POSITION;
    float3 Normal				: NORMAL;
    float2 TexCoord0			: TEXCOORD0;
};

struct VertexInputAni {
    float3 Position				: POSITION;
	float3 Normal				: NORMAL;
    float2 TexCoord0			: TEXCOORD0;
	int4   nBoneIndex			: BLENDINDICES;
	float4 fWeight				: BLENDWEIGHT;
};

struct VertexOutput 
{
    float4 Position				: POSITION;
    float3 Reflect				: TEXCOORD0;
    float3 TexCoord0			: TEXCOORD1;
    float4 Color				: TEXCOORD2;
    float4 Fog		    		: TEXCOORD3;
#ifdef BAKE_DEPTHMAP
    float DepthValue			: TEXCOORD4;
#endif
#ifdef BAKE_VELOCITY
    float2 Velocity				: TEXCOORD5;
#endif
};

struct VertexOutputShadow
{
    float4 Position				: POSITION;
    float3 Reflect				: TEXCOORD0;
    float3 TexCoord0			: TEXCOORD1;
    float4 Color				: TEXCOORD2;
    float4 Fog		    		: TEXCOORD3;
#if defined( SIMPLE_SHADOWMAP ) || defined( DEPTH_SHADOWMAP )
    float4 LightSpacePos		: TEXCOORD4;
#endif
#ifdef BAKE_DEPTHMAP
    float DepthValue			: TEXCOORD5;
#endif
#ifdef BAKE_VELOCITY
    float2 Velocity				: TEXCOORD6;
#endif
};

struct PixelOutput
{
	float4 Color				: COLOR0;
#ifdef BAKE_DEPTHMAP
	float4 Depth				: COLOR1;
#endif
#ifdef BAKE_VELOCITY
    float4 Velocity				: COLOR2;
#endif
};

//////////////////////////////////////////////////////////////////////////////////////////////
// Start Vertex Shader
//////////////////////////////////////////////////////////////////////////////////////////////
#ifdef ETERNITY_ENGINE
#define CalcDiffuse																		\
																						\
	float3 WorldViewPos = mul( float4( Input.Position.xyz, 1.0f ), g_WorldViewMat );	\
	Output.Position = mul( float4( WorldViewPos, 1.0f ), g_ProjMat );	\
	float3 WorldViewNormal = normalize( mul( Input.Normal, g_WorldViewMat ) );						\
																						\
	float4 DiffuseLight = float4( 0.0f, 0.0f, 0.0f, 1.0f );											\
	DiffuseLight = CalcDiffuseAll( DiffuseLight, WorldViewNormal, WorldViewPos );					\
																						\
	float4 Ambient = g_MaterialAmbient * g_LightAmbient;								\
	float4 Diffuse = g_MaterialDiffuse * DiffuseLight;									\
	Output.Color = Diffuse + Ambient;													\
	Output.Color.w = g_MaterialAmbient.w;												\
	Output.TexCoord0.xy = Input.TexCoord0;													\
	Output.TexCoord0.x = frac(Input.TexCoord0.x);													\
	Output.TexCoord0.z = floor(Input.TexCoord0.x);													\
	float3 WorldViewReflect = reflect( normalize( WorldViewPos ), WorldViewNormal );	\
	Output.Reflect = normalize( mul( WorldViewReflect, g_InvViewMat ) );				\
	Output.Reflect.y = 0.5f - Output.Reflect.y * 0.5f;																\
	float2 ScreenCoord = Output.Position.xy / Output.Position.w;						\
	Output.Fog.xy = ( ScreenCoord + 1.0f ) * 0.5f;										\
	Output.Fog.y = 1.0f - Output.Fog.y;													\


VertexOutput DiffuseVS( VertexInput Input ) 
{
	VertexOutput Output;
	
	CalcDiffuse;
	Output.Fog.zw = CalcFogValue( Output.Position.z );

#ifdef BAKE_DEPTHMAP
	Output.DepthValue = Output.Position.z;
#endif
#ifdef BAKE_VELOCITY
	Output.Velocity = Output.Position.xy / Output.Position.w;
	float4 PrevWorldViewProjPos = mul( float4( Input.Position.xyz, 1.0f ), g_PrevWorldViewProjMat );
	Output.Velocity -= PrevWorldViewProjPos.xy / PrevWorldViewProjPos.w;
#endif																					

	return Output;
}

VertexOutputShadow DiffuseShadowVS( VertexInput Input ) 
{
	VertexOutputShadow Output;
	
	CalcDiffuse;
	Output.Fog.zw = CalcFogValue( Output.Position.z );

#if defined( SIMPLE_SHADOWMAP ) || defined( DEPTH_SHADOWMAP )
	Output.LightSpacePos = mul( float4( Input.Position.xyz, 1.0f ) , g_WorldLightViewProjMat );
	Output.LightSpacePos.z = dot( float4( Input.Position.xyz, 1.0f ) , g_WorldLightViewProjDepth ) * Output.LightSpacePos.w;
#endif

#ifdef BAKE_DEPTHMAP
	Output.DepthValue = Output.Position.z;
#endif
#ifdef BAKE_VELOCITY
	Output.Velocity = Output.Position.xy / Output.Position.w;
	float4 PrevWorldViewProjPos = mul( float4( Input.Position.xyz, 1.0f ), g_PrevWorldViewProjMat );
	Output.Velocity -= PrevWorldViewProjPos.xy / PrevWorldViewProjPos.w;
#endif																					

	return Output;
}

#define 	CalcDiffuseAni																			\
    float3 WorldViewPos = CalcBlendPosition( Input.Position, Input.nBoneIndex, Input.fWeight );		\
	Output.Position = mul( float4( WorldViewPos, 1.f ) , g_ProjMat );								\
																									\
	float3 WorldViewNormal = CalcBlendNormal( Input.Normal, Input.nBoneIndex, Input.fWeight );		\
																									\
	float4 DiffuseLight = float4( 0.0f, 0.0f, 0.0f, 1.0f );											\
	DiffuseLight = CalcDiffuseAll( DiffuseLight, WorldViewNormal, WorldViewPos );					\
																											\
	float4 Ambient = g_MaterialAmbient * g_LightAmbient;										\
	float4 Diffuse = g_MaterialDiffuse * DiffuseLight;												\
	Output.Color = Diffuse + Ambient;																\
	Output.Color.w = g_MaterialAmbient.w;															\
	Output.TexCoord0.xy = Input.TexCoord0;														\
	Output.TexCoord0.x = frac(Input.TexCoord0.x);												\
	Output.TexCoord0.z = floor(Input.TexCoord0.x);												\
																											\
	float3 WorldViewReflect = reflect( normalize( WorldViewPos ), WorldViewNormal );		\
	Output.Reflect = normalize( mul( WorldViewReflect, g_InvViewMat ) );						\
	Output.Reflect.y = 0.5f - Output.Reflect.y * 0.5f;												\
	float2 ScreenCoord = Output.Position.xy / Output.Position.w;						\
	Output.Fog.xy = ( ScreenCoord + 1.0f ) * 0.5f;										\
	Output.Fog.y = 1.0f - Output.Fog.y;													\


VertexOutput DiffuseAniVS( VertexInputAni Input ) 
{
	VertexOutput Output;
	
	CalcDiffuseAni;
	Output.Fog.zw = CalcFogValue( Output.Position.z );
	
#ifdef BAKE_DEPTHMAP
	Output.DepthValue = Output.Position.z;
#endif
#ifdef BAKE_VELOCITY
	Output.Velocity = Output.Position.xy / Output.Position.w;
	float4 PrevWorldViewProjPos = mul( float4( WorldViewPos.xyz, 1.0f ), g_InvWorldViewPrevWVPMat );
	Output.Velocity -= PrevWorldViewProjPos.xy / PrevWorldViewProjPos.w;
#endif							

    return Output;
}

VertexOutputShadow DiffuseAniShadowVS( VertexInputAni Input  )
{
	VertexOutputShadow Output;
	
	CalcDiffuseAni;
	Output.Fog.zw = CalcFogValue( Output.Position.z );
	
#if defined( SIMPLE_SHADOWMAP ) || defined( DEPTH_SHADOWMAP )
	Output.LightSpacePos = mul( float4( WorldViewPos.xyz, 1.0f ) , g_InvViewLightViewProjMat );
	Output.LightSpacePos.z = dot( float4( WorldViewPos.xyz, 1.0f ) , g_InvViewLightViewProjDepth ) * Output.LightSpacePos.w;
#endif

#ifdef BAKE_DEPTHMAP
	Output.DepthValue = Output.Position.z;
#endif
#ifdef BAKE_VELOCITY
	Output.Velocity = Output.Position.xy / Output.Position.w;
	float4 PrevWorldViewProjPos = mul( float4( WorldViewPos.xyz, 1.0f ), g_InvWorldViewPrevWVPMat );
	Output.Velocity -= PrevWorldViewProjPos.xy / PrevWorldViewProjPos.w;
#endif							
	
    return Output;
}

#else
float4x4 g_ViewMat				: VIEW;

VertexOutput DiffuseVS( VertexInput Input ) 
{
	VertexOutput Output;
	
	Output.Position = mul( float4( Input.Position.xyz , 1.0 ) , g_WorldViewProjMat );

	float3 TransformNormal = normalize( mul( Input.Normal, g_WorldViewMat ) );
	float3 LightVec = normalize( mul( g_LightDir, g_ViewMat ) );

	float  DiffuseLight = saturate( dot( TransformNormal, LightVec ) );
	float4 Ambient = g_MaterialAmbient * g_LightAmbient;
	float4 Diffuse = g_MaterialDiffuse * g_LightDiffuse * DiffuseLight;
	Output.Color = Diffuse + Ambient;
	Output.Color.w = g_MaterialAmbient.w;
	Output.Fog = 0.0f;
	
	float3 WorldViewPos = mul( float4( Input.Position.xyz , 1.0 ) , g_ViewMat );

	Output.TexCoord0.xy = Input.TexCoord0;
	Output.TexCoord0.z = 0;
	float3 WorldViewReflect = reflect( normalize( WorldViewPos ), TransformNormal );
	Output.Reflect = normalize( mul( WorldViewReflect, g_InvViewMat ) );
	Output.Reflect.y = 0.5f - Output.Reflect.y * 0.5f;

	return Output;
}
#endif

//////////////////////////////////////////////////////////////////////////////////////////////
// Start Pixel Shader
//////////////////////////////////////////////////////////////////////////////////////////////
#ifdef _3DSMAX_
float4 CalcDiffuseColor( VertexOutput Input )
{
	float4 DiffuseTex = tex2D( g_DiffuseSampler, Input.TexCoord0 );
	float4 MaskTex = tex2D( g_MaskSampler, Input.TexCoord0 );

	float fEmissive = g_EmissivePower + g_EmissivePowerRange * cos( g_fElapsedTime * g_EmissiveAniSpeed );
	float4 EmissiveColor = g_EmissiveColor[ Input.TexCoord0.z ] * g_EmissivePower;
	float4 Result = Input.Color * DiffuseTex;
	Result.xyz = lerp( Result.xyz, EmissiveColor.xyz, MaskTex.r );

	float2 TexCoord;
	TexCoord.x = frac( atan2( Input.Reflect.x, Input.Reflect.z ) / ( 6.283185308 ) + 1.0f );
	TexCoord.y = Input.Reflect.y;
	float4 EnvTex = tex2D( g_EnvSampler, TexCoord );

	Result = Result + float4( MaskTex.yyy, 0.0f ) * EnvTex;

	return Result;
}
#else
float4 CalcDiffuseColor( VertexOutput Input )
{
	float4 DiffuseTex = tex2D( g_DiffuseSampler, Input.TexCoord0.xy );
	float4 MaskTex = tex2D( g_MaskSampler, Input.TexCoord0.xy );

	float3 SkinColor = DiffuseTex.xyz * g_SkinCoeffA.w - g_SkinCoeffD.xyz;
	SkinColor = g_SkinCoeffA.xyz - g_SkinCoeffB.xyz * sqrt( g_SkinCoeffC.xyz - SkinColor * SkinColor );

	DiffuseTex.xyz = lerp( DiffuseTex.xyz, SkinColor, MaskTex.b);	
	DiffuseTex.xyz = lerp( DiffuseTex.xyz, DiffuseTex.xyz*g_EyeColor.xyz, MaskTex.a);

	float4 EmissiveColor = g_EmissiveColor[ Input.TexCoord0.z ];
	float4 Result = Input.Color * DiffuseTex;
	Result.xyz = lerp( Result.xyz, EmissiveColor.xyz, EmissiveColor.a*MaskTex.r );

	float2 TexCoord;
	TexCoord.x = frac( atan2( Input.Reflect.x, Input.Reflect.z ) / ( 6.283185308 ) + 1.0f );
	TexCoord.y = Input.Reflect.y;
	float4 EnvTex = tex2D( g_EnvSampler, TexCoord );

	Result = Result + float4( MaskTex.yyy, 0.0f ) * EnvTex;
	return Result;
}
#endif

PixelOutput DiffusePS( VertexOutput Input ) : COLOR
{
	PixelOutput Output;

	Output.Color = CalcDiffuseColor( Input );
	Output.Color.xyz = CalcFogColor( Output.Color.xyz, Input.Fog );

#ifdef BAKE_DEPTHMAP
	Output.Depth = float4( Input.DepthValue.x, 0.0f, 0.0f, 1.0f );
#endif
#ifdef BAKE_VELOCITY
	Output.Velocity = float4( Input.Velocity, 0.0f, 1.0f );
#endif

	return Output;
}

PixelOutput DiffuseShadowPS( VertexOutputShadow Input ) : COLOR
{
	PixelOutput Output;

	Output.Color = CalcDiffuseColor( ( VertexOutput )Input );
#if defined( SIMPLE_SHADOWMAP ) || defined( DEPTH_SHADOWMAP )
	Output.Color.xyz *= CalcShadow( Input.LightSpacePos );
#endif
	Output.Color.xyz = CalcFogColor( Output.Color.xyz, Input.Fog );

#ifdef BAKE_DEPTHMAP
	Output.Depth = float4( Input.DepthValue.x, 0.0f, 0.0f, 1.0f );
#endif
#ifdef BAKE_VELOCITY
	Output.Velocity = float4( Input.Velocity, 0.0f, 1.0f );
#endif

	return Output;
}


//////////////////////////////////////////////////////////////////////////////////////////////
// Start Technique
//////////////////////////////////////////////////////////////////////////////////////////////
#ifdef ETERNITY_ENGINE
technique DiffuseTech
{
    pass p0 
    {		
		VertexShader = compile vs_2_0 DiffuseVS();
		PixelShader  = compile ps_2_0 DiffusePS();
    }
}
technique DiffuseAniTech
{
    pass p0 
    {		
		VertexShader = compile vs_2_0 DiffuseAniVS();
		PixelShader  = compile ps_2_0 DiffusePS();
    }
}
technique DiffuseShadowTech
{
    pass p0 
    {		
		VertexShader = compile vs_2_0 DiffuseShadowVS();
		PixelShader  = compile ps_2_0 DiffusePS();//DiffuseShadowPS();		// ���� ������ ����.
    }
}
technique DiffuseAniShadowTech
{
    pass p0 
    {		
		VertexShader = compile vs_2_0 DiffuseAniShadowVS();
		PixelShader  = compile ps_2_0 DiffusePS();//DiffuseShadowPS();		// ���� ������ ����.
    }
}
#else
technique DiffuseTech
{
    pass p0 
    {		
		VertexShader = compile vs_2_0 DiffuseVS();
		PixelShader  = compile ps_2_0 DiffusePS();
    }
}
#endif

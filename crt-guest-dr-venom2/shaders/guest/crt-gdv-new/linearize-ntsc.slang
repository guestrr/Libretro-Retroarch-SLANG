#version 450

#pragma format R32G32B32A32_SFLOAT

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float decon;
	float deconstr;
	float GAMMA_INPUT;
	float inter;
	float interm;
	float intres;
} params;

#pragma parameter GAMMA_INPUT "Gamma Input" 2.4 1.0 5.0 0.05
#define GAMMA_INPUT params.GAMMA_INPUT

#pragma parameter bogus_deconvergence "[ HORIZONTAL DECONVERGENCE ]:" 0.0 0.0 1.0 1.0

#pragma parameter decon "          Horizontal Deconvergence Range" 1.0 -8.0 8.0 0.250
#define decon        params.decon     // Horizontal deconvergence range

#pragma parameter deconstr "          Horizontal Deconvergence Strength" 0.0 0.0 1.0 0.05
#define deconstr     params.deconstr  // Horizontal deconvergence strength

#pragma parameter bogus_interlacing "[ INTERLACING OPTIONS ]: " 0.0 0.0 0.0 1.0

#pragma parameter inter "          Interlace Trigger Resolution :" 350.0 0.0 800.0 25.0
#define inter         params.inter     // interlace resolution

#pragma parameter interm "          Interlace Mode: OFF, Normal_1, Normal_2..." 1.0 0.0 4.0 1.0
#define interm         params.interm     // interlace mode 

#pragma parameter intres "          Internal Resolution: 1.0:240p, 1.5...y-dowsample" 0.0 0.0 4.0 0.5
#define intres         params.intres     // interlace resolution

#define SourceSize  params.SourceSize

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.00001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D PrePass;

#define COMPAT_TEXTURE(c,d) texture(c,d)

void main()
{
	vec2 dx1 =  vec2(1.0/SourceSize.x, 0.0)*decon;
	vec2 dx2 = -dx1*decon;
	vec2 dy  = vec2(0.0, 1.0/SourceSize.y);
	
	vec3  c1 = COMPAT_TEXTURE(PrePass, vTexCoord).rgb;
	vec3  c2 = COMPAT_TEXTURE(PrePass, vTexCoord + dy).rgb;
	
	float r1 = COMPAT_TEXTURE(PrePass, vTexCoord + dx1).r;
	float b1 = COMPAT_TEXTURE(PrePass, vTexCoord + dx2).b;
	float r2 = COMPAT_TEXTURE(PrePass, vTexCoord + dx1 + dy).r;
	float b2 = COMPAT_TEXTURE(PrePass, vTexCoord + dx2 + dy).b;

	vec3 res1 = c1;
	vec3 res2 = c2;
	
	res1.rb = mix(c1.rb, vec2(r1,b1), deconstr);
	res2.rb = mix(c2.rb, vec2(r2,b2), deconstr);
	vec3 res = res1;

	float intera = 1.0;
	float yres_div = 1.0; if (intres > 1.25) yres_div = intres;
	
	if (inter < SourceSize.y/yres_div && interm > 0.5 && intres != 1.0)
	{
		intera = 0.0;
		float line_no  = floor(mod(params.OriginalSize.y*vTexCoord.y, 2.0));		
		float frame_no = floor(mod(float(params.FrameCount),2.0));
		float ii = (interm == 3.0) ? 0.5 : abs(line_no-frame_no);	

		if (interm == 1.0 || interm == 3.0) { res = mix(res1, res2, ii); intera = 0.5; }
		if (interm == 2.0) { res = mix(res1, res2, ii); res = normalize(res + 1e-5) * length(min(res,res1)); intera = 0.0; }
	}
	
	float gamma_in = 1.0/GAMMA_INPUT;
	if (vTexCoord.x > 0.5) gamma_in = intera;	
	
	FragColor = vec4(pow(res, vec3(GAMMA_INPUT)), gamma_in);
}
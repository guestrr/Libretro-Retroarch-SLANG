#version 450

#pragma format R32G32B32A32_SFLOAT

layout(push_constant) uniform Push
{
	vec4 OriginalSize;
	vec4 OutputSize;
	vec4 SourceSize;
	uint FrameCount;
	float GAMMA_INPUT;
	float inter;
	float interm;
} params;


layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;


#pragma parameter GAMMA_INPUT "Gamma Input" 2.4 1.0 5.0 0.05
#define GAMMA_INPUT params.GAMMA_INPUT

#pragma parameter bogus_interlacing "[ INTERLACING OPTIONS ]: " 0.0 0.0 0.0 1.0

#pragma parameter inter "          Interlace Trigger Resolution :" 350.0 0.0 800.0 25.0
#define inter         params.inter     // interlace resolution

#pragma parameter interm "          Interlace Mode: OFF, Normal_1, Normal_2..." 1.0 0.0 4.0 1.0
#define interm         params.interm     // interlace mode 


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.000001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D PrePass;

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define SourceSize  params.SourceSize

void main()
{
	vec3  c1 = COMPAT_TEXTURE(PrePass, vTexCoord).rgb;
	vec3  c2 = COMPAT_TEXTURE(PrePass, vTexCoord + vec2(0.0, 1.0/params.OriginalSize.y)).rgb;
	vec3  c  = c1;

	float intera = 1.0;
	
	if (inter < params.OriginalSize.y && interm > 0.5)
	{
		intera = 0.0;
		float line_no  = floor(mod(params.OriginalSize.y*vTexCoord.y, 2.0));		
		float frame_no = floor(mod(float(params.FrameCount),2.0));
		float ii = (interm == 3.0) ? 0.5 : abs(line_no-frame_no);	

		if (interm == 1.0 || interm == 3.0) { c = mix(c1, c2, ii); intera = 0.5; }
		if (interm == 2.0) { c = mix(c1, c2, ii);  c = normalize(c1 + 1e-5) * length(min(c,c1)); intera = 0.0; }
	}
	
	float gamma_in = 1.0/GAMMA_INPUT;
	if (vTexCoord.x > 0.5) gamma_in = intera;
	
	FragColor = vec4(pow(c, vec3(GAMMA_INPUT)), gamma_in);
}
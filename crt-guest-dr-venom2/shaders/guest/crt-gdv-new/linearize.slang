#version 450

/*
   Interlacing
   
   Copyright (C) 2020 guest(r) - guest.r@gmail.com

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
   
*/ 

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
	float inters;
	float iscan;
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

#pragma parameter interm "          Interlace Mode: OFF, Normal, Interpolation" 1.0 0.0 2.0 1.0
#define interm         params.interm     // interlace mode 

#pragma parameter inters "          Interlacing Effect Smoothness" 0.0 0.0 0.5 0.05 // // Joint parameter with main pass, values must match
#define inters  params.inters     // interlacing effect smoothing

#pragma parameter iscan "          Interlacing Scanline Effect" 0.40 0.0 1.0 0.05
#define iscan  params.iscan     // interlacing effect scanlining


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


vec3 transplant (vec3 tar, vec3 ref)
{
	float t = max(max(tar.r,tar.g),tar.b) + 0.00001;
	float r = max(max(ref.r,ref.g),ref.b);
	return tar * r / t;
}


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
		float ii = abs(line_no-frame_no);
		if (interm == 1.0) { c = max(c1*ii, (1.0-iscan)*min(c1,c2)); c = transplant(mix(c2, c1, ii), c); }
	}
	
	float gamma_in = 1.0/GAMMA_INPUT;
	if (vTexCoord.x > 0.5) gamma_in = intera;
	
	FragColor = vec4(pow(c, vec3(GAMMA_INPUT)), gamma_in);
}
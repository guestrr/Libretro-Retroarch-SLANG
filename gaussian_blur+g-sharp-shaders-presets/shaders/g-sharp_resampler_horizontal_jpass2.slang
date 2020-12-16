#version 450

/*
   G-sharp resampler - horizontal pass2, dynamic range, resizable
   
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

   Anti-Ringing inspired by Hyllian
   
*/ 

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float SIGMA_JP2;
	float JPSHARP02;
	float JPAR2;
	float JPSHAR2;
} params;


// Horizontal pass joint parameters, all changes must match

#pragma parameter bogus-line3 "-------------------------------------------------" 0.0 0.0 0.0 0.0

#pragma parameter JPSHARP02 "Filter Range" 1.2 1.0 8.0 0.1
#define JPSHARP02 params.JPSHARP02

#pragma parameter SIGMA_JP2 "Blur Sigma" 0.75 0.1 7.0 0.05
#define SIGMA_JP2 params.SIGMA_JP2

#pragma parameter JPSHAR2 "Sharpness Definition" 0.5 0.0 2.0 0.05
#define JPSHAR2 params.JPSHAR2

#pragma parameter JPAR2 "Anti-Ringing" 0.5 0.0 1.0 0.1
#define JPAR2 params.JPAR2

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
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define SourceSize params.SourceSize

float invsqrsigma = 1.0/(2.0*SIGMA_JP2*SIGMA_JP2);

float gaussian(float x)
{
	return exp(-x*x*invsqrsigma);
}

void main()
{
	float f = fract(SourceSize.x * vTexCoord.x);
	f = 0.5 - f;
	vec2 tex = floor(SourceSize.xy * vTexCoord)*SourceSize.zw + 0.5*SourceSize.zw;
	vec3 color = 0.0.xxx;
	vec2 dx  = vec2(SourceSize.z, 0.0);

	float w;
	float wsum = 0.0;
	vec3 pixel;

	vec3 cmax = 0.0.xxx;
	vec3 cmin = 1.0.xxx;
	float sharp = gaussian(JPSHARP02);
	float maxsharp = 0.21;
	float FPR = JPSHARP02;
	float fpx;

	float LOOPSIZE = ceil(2.0*FPR);	
	float n = -LOOPSIZE;
	
	do
	{
		pixel  = COMPAT_TEXTURE(Source, tex + n*dx).rgb;
		w = gaussian(n+f) - sharp; 
		fpx = abs(n+f-sign(n)*FPR)/FPR;
		if (abs(n) <= 1.5*FPR) { cmax = max(cmax, pixel); cmin = min(cmin, pixel); }
		if (w < 0.0) w = clamp(w, mix(-maxsharp, 0.0, pow(fpx, JPSHAR2)), 0.0);
	
		color = color + w * pixel;
		wsum  = wsum+ w;
		n = n + 1.0;
			
	} while (n <= LOOPSIZE);

	color = color / wsum;
	
	color = mix(clamp(color, 0.0, 1.0), clamp(color, cmin, cmax), JPAR2);
		
	FragColor = vec4(color, 1.0);
}
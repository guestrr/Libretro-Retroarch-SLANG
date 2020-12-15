#version 450

/*
   G-sharp deblur (separate iteration) - dynamic range, resizable
   
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

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float DRANGE2;
	float DEBLUR2;
	float DSTEP2;
	float ARR2;
	float DIT2;
	float SMARTLOW2;
	float SMARTHIGH2;
	float SMETHOD2;
	float SMSTRENGTH2;
} params;

#pragma parameter bogus-line5 "-------------------------------------------------" 0.0 0.0 0.0 0.0 

#pragma parameter DRANGE2 "Deblur Kernel Size" 2.0 1.0 10.0 1.0
#define DRANGE2 params.DRANGE2

#pragma parameter DSTEP2 "Deblur Range Step" 1.0 1.0 5.0 1.0
#define DSTEP2 params.DSTEP2

#pragma parameter DIT2 "Deblur Iterations" 1.0 1.0 3.0 1.0
#define DIT2 params.DIT2

#pragma parameter DEBLUR2 "Deblur Strength" 0.0 0.0 25.0 1.0
#define DEBLUR2 params.DEBLUR2

#pragma parameter SMARTLOW2 "Smart Deblur Smoothing Threshold" 0.0 0.0 1.0 0.05
#define SMARTLOW2 params.SMARTLOW2

#pragma parameter SMARTHIGH2 "Smart Deblur Sharp  Threshold" 0.0 0.0 1.0 0.05
#define SMARTHIGH2 params.SMARTHIGH2

#pragma parameter SMETHOD2 "Smart Deblur Method" 0.5 0.0 1.0 0.1
#define SMETHOD2 params.SMETHOD2

#pragma parameter SMSTRENGTH2 "Smart Deblur Smoothing Strength" 1.0 0.0 1.0 0.1
#define SMSTRENGTH2 params.SMSTRENGTH2

#pragma parameter ARR2 "Deblur Anti-ringing Radius" 1.0 0.5 4.0 0.5
#define ARR2 params.ARR2

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

void main()
{
	vec3 color = COMPAT_TEXTURE(Source, vTexCoord).rgb;

	if (DEBLUR2 > 0.0)
	{
		vec2 dx  = vec2(SourceSize.z, 0.0);	
		vec2 dy  = vec2(0.0, SourceSize.w);

		vec3 pixel, orig;
		float x;
		vec3  res;
		float w;
		vec3 cmax = 0.0.xxx;
		vec3 cmin = 1.0.xxx;
		
		float LOOPSIZE = DSTEP2*DRANGE2;
		float y = -LOOPSIZE;

		do
		{
			x = -LOOPSIZE;
	
			do
			{
				pixel  = COMPAT_TEXTURE(Source, vTexCoord + x*dx + y*dy).rgb;
				cmax = max(cmax, pixel); cmin = min(cmin, pixel);
				x = x + DSTEP2;
			
			} while (x <= LOOPSIZE);
		
			y = y + DSTEP2;
		
		} while (y <= LOOPSIZE);	
	
		res = color;
		vec3 contrast = cmax - cmin + 0.000001;
		vec3 df1, df2, ratio;
		
		x = 1.0;
		do
		{
			df1 = max(res-cmin, 0.0);
			df2 = max(cmax-res, 0.0);
			ratio = abs(df1-df2)/(df1+df2+0.0000001);
			df1 = max(smoothstep( -0.0001, 1.0, df1/contrast), 0.0001);
			df2 = max(smoothstep( -0.0001, 1.0, df2/contrast), 0.0001);
			res = clamp(mix(color, (cmax*df1 + cmin*df2)/(df1+df2), DEBLUR2*ratio), cmin, cmax);
			x = x + 1.0;
			
		} while (x <= DIT2);
		
		vec3 c00 = COMPAT_TEXTURE(Source, vTexCoord  -dx  -dy).rgb;
		vec3 c20 = COMPAT_TEXTURE(Source, vTexCoord  +dx  -dy).rgb;		
		vec3 c02 = COMPAT_TEXTURE(Source, vTexCoord  -dx  +dy).rgb;		
		vec3 c22 = COMPAT_TEXTURE(Source, vTexCoord  +dx  +dy).rgb;	

		vec3 edge = abs(c00-c22) + abs(c20-c02);
		
		float e = max(max(edge.r,edge.g),edge.b);
		e = smoothstep(0.0, 5.0/255.0, e);
		
		orig = color;
		color = mix(color, res, e);
		
		float mx = 0.0;
		float nx = 3.0;
		vec3 nmin;
		vec3 nmax;
		nmax = 0.0.xxx;
		nmin = 1.0.xxx;
		
		dx = vec2(1.0/1920.0, 0.0);
		dy = vec2(0.0, 1.0/1080.0);

		LOOPSIZE = ARR2;
		
		y = -LOOPSIZE;
		
		do
		{
			x = -LOOPSIZE;
	
			do
			{
				pixel  = COMPAT_TEXTURE(Source, vTexCoord + x*dx + y*dy).rgb;
				nmin = min(nmin, pixel);
				nmax = max(nmax, pixel);
				x = x + 1.0;
			
			} while (x <= LOOPSIZE);
		
			y = y + 1.0;
		
		} while (y <= LOOPSIZE);

		color = clamp(color, nmin, nmax);

		vec3 ccalc = mix(abs(orig-color), nmax - nmin, SMETHOD2);
		float scalc = max(max(ccalc.r,ccalc.g), ccalc.b);

		contrast = smoothstep (min(SMARTLOW2,SMARTHIGH2-0.00001), SMARTHIGH2, scalc.xxx);
		
		color = mix(color, mix(orig, color, contrast), SMSTRENGTH2);
	}	

	FragColor = vec4(color, 1.0);
}

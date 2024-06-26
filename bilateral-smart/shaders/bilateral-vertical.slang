#version 450

/*
   Bilateral - Smart - Vertical
   
   Copyright (C) 2024 guest(r)

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
	float FRANGE;
	float FBSMOOTH;
	float FSIGMA;
} params;


#pragma parameter FRANGE "Filter Range" 3.0 1.0 10.0 1.0
#define FRANGE params.FRANGE

#pragma parameter FBSMOOTH "Filter Base Smoothing" 0.35 0.05 1.0 0.025
#define FBSMOOTH params.FBSMOOTH

#pragma parameter FSIGMA "Filter Strength" 0.65 0.15 1.5 0.05
float FSIGMA1 = 1.0/(params.FSIGMA);

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
layout(set = 0, binding = 2) uniform sampler2D Source;

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define SourceSize params.SourceSize

float wt(vec3 A, vec3 B)
{	
	return clamp(FBSMOOTH - 2.33*dot(abs(A-B),1.0.xxx)/(dot(A+B,1.0.xxx)+1.0), 0.0, 0.25);
}


float getw(float x, vec3 c, vec3 p)
{
	float y = pow(1.0-x, FSIGMA1);
	float d = wt(c,p);
	return y*d;
}


void main()
{
	vec2 pos = vTexCoord * SourceSize.xy;
	float f =  0.5-fract(pos.y);
	vec2 tex = floor(pos)*SourceSize.zw + 0.5*SourceSize.zw;
	vec2 dy  = vec2(0.0,SourceSize.w);
	
	float w, fp;
	float wsum = 0.25;
	vec3 pixel;
	float FPR = FRANGE;
	float FPR1 = 1.0/FPR;
	float LOOPSIZE = FPR;
	float y = 1.0;

	vec3 comp = COMPAT_TEXTURE(Source, tex).rgb;
	vec3 color = comp * wsum;
	
	do
	{
		pixel  = COMPAT_TEXTURE(Source, tex - y*dy).rgb;		
		fp = min(abs(-y+f),FPR)*FPR1;
		w = getw(fp,comp,pixel);
		color = color + w * pixel;
		wsum   = wsum + w;

		pixel  = COMPAT_TEXTURE(Source, tex + y*dy).rgb;		
		fp = min(abs( y+f),FPR)*FPR1;
		w = getw(fp,comp,pixel);		
		color = color + w * pixel;
		wsum   = wsum + w;

		y = y + 1.0;
		
	} while (y <= LOOPSIZE);

	color = color / wsum;
	
	FragColor = vec4(color, 1.0);
}
#version 450

/*
   Deblur - ScaleFX version
   
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
	float SFXCRISP;
	float SFXSHARP;

} params;


#pragma parameter SFXSHARP "ScaleFX Sharpness" 0.70 0.0 1.0 0.05
#define SFXSHARP params.SFXSHARP

#pragma parameter SFXCRISP "ScaleFX Crispness" 2.5 1.0 7.0 0.50
#define SFXCRISP params.SFXCRISP

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
layout(set = 0, binding = 3) uniform sampler2D SfxPass;

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define SourceSize params.SourceSize


void main()
{
		vec3 color = COMPAT_TEXTURE(Source, vTexCoord).rgb;
		
		vec3 pixel, pixel1;
		float x;
		float LOOPSIZE = 1.0;

		vec2 tex = floor(3.0*params.OriginalSize.xy * vTexCoord)*params.OriginalSize.zw/3.0 + 0.5/3.0*params.OriginalSize.zw;

		vec2 dx = vec2(params.OriginalSize.z, 0.0)/3.0;
		vec2 dy = vec2(0.0, params.OriginalSize.w)/3.0;

		float w;
		float wsum = 0.0;
		vec3 ref = 0.0.xxx;
		vec3 dif;
		float y = -LOOPSIZE;
		
		do
		{
			x = -LOOPSIZE;
	
			do
			{
				pixel  = COMPAT_TEXTURE(SfxPass, tex + x*dx + y*dy).rgb;
				dif = color - pixel;
				w = dot(dif, dif);
				w = 1.0/(pow(10.0*w + 0.0001, SFXCRISP));
				ref = ref + w*pixel;
				wsum = wsum + w;
				x = x + 1.0;
			
			} while (x <= LOOPSIZE);
		
			y = y + 1.0;
		
		} while (y <= LOOPSIZE);

		ref = ref/wsum;
		
		vec3 color1 = mix(color*color, ref*ref, SFXSHARP); color1 = sqrt(color1);
		vec3 color2 = mix(sqrt(color), sqrt(ref), SFXSHARP); color2 = color2*color2; 

		float k1 = dot(ref-color1,ref-color1) + 0.000001;
		float k2 = dot(ref-color2,ref-color2) + 0.000001;
		
		color = (color1*k2 + color2*k1)/(k1+k2);

		FragColor = vec4(color, 1.0);
}

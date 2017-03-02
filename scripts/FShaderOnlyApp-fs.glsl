#version 300 es
precision mediump float;

flat in int   vi_i;
flat in int   vi_j;
in float vf_x;
in float vf_y;

uniform vec2               resolution;
uniform vec2               dataSize;
uniform mediump isampler2D u_texture;

uniform float              u_minValue;
uniform vec4               u_minColor;
uniform sampler2D          u_colormap;
uniform float              u_maxValue;
uniform vec4               u_maxColor;

in vec4 outColorVS;
flat in int calculated;

out vec4 outColor;

void main() {
    if (calculated == 1) {
        outColor = outColorVS;
    } else {
        int iMinValue = int(u_minValue);
        int fromX = int( float(vi_i) * dataSize.x / resolution.x );
        int fromY = int( float(vi_j) * dataSize.y / resolution.y );
        int toX   = int( (float(vi_i) + 1.0) * dataSize.x / resolution.x );
        int toY   = int( (float(vi_j) + 1.0) * dataSize.y / resolution.y );
        if (toX == fromX) toX = toX + 1;
        if (toY == fromY) toY = toY + 1;
        int maxValue = -32767;
        for (int x=fromX; x < toX; x++) {
            for (int y=fromY; y < toY; y++) {
                ivec4 value = texelFetch(u_texture, ivec2(x,y), 0);
                if (maxValue < value.x) maxValue = value.x;
            }
        }
        float z = float(maxValue);
        if (z <= u_minValue) {
            outColor = u_minColor;
        } else if (u_maxValue <= z) {
            outColor = u_maxColor;
        } else {
             outColor = texelFetch ( u_colormap, ivec2( maxValue - iMinValue , 0 ),0 );
        }
    }
}

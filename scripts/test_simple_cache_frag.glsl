#version 300 es
precision mediump float;
precision mediump int;

const int FILTER_TYPE_MIN           = 1;        // "Minimum value" detektor
const int FILTER_TYPE_MAX           = 2;        // "Maximum value" detektor
const int FILTER_TYPE_AVG           = 3;        // "Average value" detektor
const int FILTER_TYPE_DEBUG_NONE    = 0;        // DEBUG-only: nincs detektor, frame buffer tartalma nyersen jelenjen meg
const int FILTER_TYPE_DEBUG_A       = -1;       // DEBUG-only
const int FILTER_TYPE_DEBUG_B       = -2;       // DEBUG-only
const int FILTER_TYPE_DEBUG_C       = -3;       // DEBUG-only

uniform mediump sampler2D       u_cache_fb;
uniform int                     u_filter_type;

out vec4                        outColor;

vec4 getColorFromPaletteTexture(float pValue) {
    //TODO: színskála-textura alapján határozni meg a színt
    return vec4(pValue, 0.0, 0.0, 1.0);
}

void main() {
    //  A másik shader program, már minden egyes pixel-re kiszámolta az értékeket,
    //      és eltárolta a framebuffer-be.
    vec4 vec4CalcValue = texelFetch(u_cache_fb, ivec2(gl_FragCoord), 0);

    //  Már csak az a kérdés, hogy a framebuffer különböző
    //      szincsatornáiban eltárolt különféle értékek közül
    //      melyiket kell megjeleníteni.
    if (u_filter_type == FILTER_TYPE_MIN) {
        outColor = getColorFromPaletteTexture(vec4CalcValue.r);
    } else if (u_filter_type == FILTER_TYPE_MAX) {
        outColor = getColorFromPaletteTexture(vec4CalcValue.g);
    }
    // ---------------------------------------------------------------
    //  Csak DEBUG célra használjuk:
    //      (Az "_A", "_B", "_C" ... szabadon variálhatók, az aktuális hibakereséshez.)
    else if (u_filter_type == FILTER_TYPE_DEBUG_NONE) {
        //      A különböző színcsatornákban eltárolt különböző értékeket
        //      egyetlen színné összemosva jelenítjük meg.
        outColor = vec4CalcValue;
    } else if (u_filter_type == FILTER_TYPE_DEBUG_A) {
        outColor = vec4(0.0, 0.0, vec4CalcValue.b, 1.0 );
    } else if (u_filter_type == FILTER_TYPE_DEBUG_B) {
        outColor = vec4(0.0, vec4CalcValue.g, vec4CalcValue.b, 1.0 );
    } else if (u_filter_type == FILTER_TYPE_DEBUG_C) {
        outColor = vec4CalcValue;
    }
    // ---------------------------------------------------------------
    else {
        //TODO: paraméterként az alkalmazásnak kellene átadnia.....
        outColor = vec4(0.0, 1.0, 1.0, 1.0 );
    }
}
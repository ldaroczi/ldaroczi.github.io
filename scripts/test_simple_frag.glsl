#version 300 es
precision mediump float;

//  A MAP-ben azt kapjuk meg,
//      hogy a page adott pixel-ének számításához
//      az adattextúra hányadik sorától és oszlopától
//      hányadik soráig és oszlopáig kell bejárnunk a texel-eket.
//
//      Csak arra kell figyelnünk, hogy a mapping csupán az első page-re - azaz a (0,0)-ra --
//      tartalmazza a -tól/-ig texel-koordinátákat,
//      ezért a kapott adatokat el kell tolnunk az aktuális page-re kalkulált offset-tel!
uniform mediump isampler2D u_pixel2TexelMap;

// A megjelenítendő adatokat tartalmazó textura.
//      FIGYELJ!!!
//      A maximális helykihasználás érdekében sorfolytonosan kezeljük,
//      azaz függetlenül az adataink logikai (pDataSizeX, pDataSizeY) felbontásától,
//      kihasználjuk a "pDataSizeX" utána jövő oszlopokat is.
//        "Logikai" felbontás   "Fizikai" tárolás
//              aaaaa           xxxxxbbbbbccccc
//              bbbbb           ddddd..........
//              ccccc           ...............
//              ddddd           ...............
//              .....           ...............
//      Konverzióra lásd lent: getPhysicalPosition()
uniform mediump isampler2D u_dataTexture;

//  Az adat-textura az adatokkat milyen logikai felbontásban, hány oszlopban tárolja,
//      függetlenül a textúra fizikai méretétől.
//      A helykihasználás és -maximalizálás érdekében sorfolytonos a tárolás.
uniform int u_dataArrayTexelWidth;

//  A canvas mérete pixelben, azaz a fizikai felbontás.
//      Figyelj! Ne keverd össze a u_viewportDataSize értékkel, amely a logikai felbontás.
uniform ivec2 u_pagePixelSize;

//  A GUI zoom funkciója azt határozza meg, hogy a canvas-en (bármekkora is a felbontása)
//      mennyi elemi adatot kell megjeleníeni (hány oszlop és hány sor mérési adatot).
uniform ivec2 u_pageTexelSize;

//  Az éppen megjelenítés alatt álló viewport sarka melyik logikai pixelnek felel meg,
//      azaz a teljes mérési tömbünkre nézve pixelben kifejezve.
//      FIGYELJ!!!
//      Az alkalmazás a canvas BAL FELSŐ sarkára vonatkozóan vezeti ezt az értéket,
//      AZONBAN itt, a fragment shader-ben, a BAL ALSÓ SAROK az origó, tehát arra vonatkozóan számolunk.
//      A HÍVÓNAK kell átszámolnia az értéket!!!
uniform ivec2 u_viewportPixelOffset;

//  Az előző menetben kiszámolt értékeket tartalmazó framebuffer
uniform mediump sampler2D u_cache_fb;
uniform ivec2 u_cacheDeltaPixelOffset;          // a cache fizikai pixelei mennyivel vannak elcsúszva a most számított fizikai pixelekhez képest?
uniform ivec2 u_needRecalcFromLogicalPixel;     // A terület, amelyet újra kell számolni, nem jó az előző állapot (pl. új adasrok érkeztek)
uniform ivec2 u_needRecalcToLogicalPixel;

out vec4 outColor;

//ivec2 BUG_getPhysicalPosition(ivec2 pLogicalTexelPosition, vec2 pPhysicalResolution) {
//    // BUG!!!
//    //      Sajnos csak float-os MOD van ?!?!?
//    //      És ez használhatatlan a számunkra, pontatlan értéket ad vissza,
//    //      amely miatt sok hibás (+/- 1 texel eltérés) texel-olvasást okozott........
//    float logPos = float(pLogicalTexelPosition.y * u_dataArrayTexelWidth + pLogicalTexelPosition.x);
//    vec2 physPos = vec2( mod(logPos, pPhysicalResolution.x), floor(logPos / pPhysicalResolution.x) );
//    return( ivec2(physPos) );
//}

ivec2 getPhysicalPosition(ivec2 pLogicalTexelPosition, ivec2 pPhysicalResolution) {
    int logPos = pLogicalTexelPosition.y * u_dataArrayTexelWidth + pLogicalTexelPosition.x;
    return ivec2(
        logPos % pPhysicalResolution.x,     //Szuper van C-szerű moduló operátor is :-) Köszi Gábor
        logPos / pPhysicalResolution.x
    );
}

void main() {
    //  Az éppen számolás alatt álló képernyő-pixel
    //      melyik mérési adatnak felel meg a teljes adathalmazunkban?
    //      A (0,0) pont az első scan söprés első frekvenciája.
    ivec2 physicalPixel = ivec2(gl_FragCoord);
    ivec2 logicalPixel = u_viewportPixelOffset + physicalPixel;

    ivec2 cachePixel = physicalPixel + u_cacheDeltaPixelOffset;

    bool needRecalculation = true;
    if (
        logicalPixel.x >= u_needRecalcFromLogicalPixel.x
        && logicalPixel.y >= u_needRecalcFromLogicalPixel.y
        && logicalPixel.x <= u_needRecalcToLogicalPixel.x
        && logicalPixel.y <= u_needRecalcToLogicalPixel.y
    ) {
        needRecalculation = true;
    } else if (
        cachePixel.x >= 0
        && cachePixel.y >= 0
        && cachePixel.x <= (u_pagePixelSize.x - 1)
        && cachePixel.y <= (u_pagePixelSize.y - 1)
    ) {
        vec4 cacheValue = texelFetch(u_cache_fb, cachePixel, 0);
        needRecalculation = false;

        //TODO: ezt csak ideiglenesen: kap egy kicsi zöldes árnyalatot, hogy lássuk melyek a másolódott területek
//        outColor = vec4(cacheValue.x, 0.2, 0.0, 1.0 );
        outColor = cacheValue;
    }

    if (needRecalculation) {
        // A "tömbméret" ahogy az adatokat fizikailag sorfolytosan(!) tároljuk a textúrában:
        //vec2 dataPhysicalResolution = vec2( textureSize(u_dataTexture, 0) );
        ivec2 dataPhysicalResolution = textureSize(u_dataTexture, 0);

        ivec2 thisPage =    // canvas felbontása alapján hányadik(xy) lapon van?
            ivec2(
                floor( float(logicalPixel.x) / float(u_pagePixelSize.x) ),
                floor( float(logicalPixel.y) / float(u_pagePixelSize.y) )
            );
        ivec2 thisPageTexelOffset = thisPage * u_pageTexelSize;

        //  Már tudjuk, melyik page-en található
        //      az éppen számítás alatt álló fragment-ünk, azaz a fizikai pixel-ünk.
        //
        //      Ebből már tudjuk azt is,
        //      hogy a page-nek hányadik sora és oszlopa (offset).
        //
        //      Ebből pedig tudjuk azt a mapping-ből,
        //      hogy mely texel-területet kell bejárnunk az adat-textúránkban.
        //      Illetve kellene bejárnunk, ha a (0,0) page-ről lenne szó....
        //      ... ha nem, akkor majd annyival el kell tolnunk, ahányadik (?,?)
        //      page-en vagyunk, lásd "thisPageTexelOffset".
        ivec2 pixelOffsetOnThisPage = logicalPixel - thisPage * u_pagePixelSize;
        ivec4 colMap = texelFetch(u_pixel2TexelMap, ivec2(pixelOffsetOnThisPage.x, 0), 0);
        ivec4 rowMap = texelFetch(u_pixel2TexelMap, ivec2(pixelOffsetOnThisPage.y, 1), 0);

        //  Ok, kezdjük végre el a texel-bejárást.
        //      A mapping megadta a határokat, R-érték = "-tól", G-érték = "-ig"
        ivec4 ivec4CalcValue = ivec4(32767, 0, 0, 0);
        int debugCountErr = 0;
        for (int x=colMap.r; x < colMap.g +1; x++) {
            for (int y=rowMap.r; y < rowMap.g +1; y++) {
                // Tudod, ugye? A mapping csak a (0,0) page-re ad infot, toljuk el, ha másikon vagyunk:
                ivec2 logicalTexelPos = ivec2(x,y) + thisPageTexelOffset;

                //  A konverzióban használt MOD miatt kell az X-re ellenőrizni,
                //      különben vízszintesen sokszorozódik a kép zoom-OUT esetén a határon kívüli területen.
                //  Függőlegesen nincs ilyen gond, a határon kívüli terület fekete lesz.
                if (logicalTexelPos.x >= 0 && logicalTexelPos.x < u_dataArrayTexelWidth) {
                    // A "tömörített" texel-tárolásunk miatt más a texel valós koordinátája:
                    ivec2 physicalTexelPos = getPhysicalPosition(logicalTexelPos, dataPhysicalResolution);
                    ivec4 texel = texelFetch(u_dataTexture, physicalTexelPos, 0);
                    int value = texel.x;
                    //TODO: bevezetni a NULL/undefined értéket
                    ivec4CalcValue.r = min(ivec4CalcValue.r, value);
                    ivec4CalcValue.g = max(ivec4CalcValue.g, value);
                    //TODO: count, sum értékeket is gyűjteni a többi színkomponensbe

                    //-- ~ getPhysicalPosition
                    ivec2 PREVphysicalTexelPos = getPhysicalPosition(logicalTexelPos+ivec2(-1,0), dataPhysicalResolution);
                    if (physicalTexelPos.x != PREVphysicalTexelPos.x + 1) debugCountErr++;
                }
            }
        }

        //DEBUG info  ---------------------------
        ivec4CalcValue.b = min(debugCountErr * 10000, 20000);
        //---------------------------------------

        //TODO: ezt csak ideiglenesen: kap egy kicsi kékes árnyalatot, hogy lássuk melyek a számolódott területek
//        outColor = vec4(float(ivec4CalcValue.x)/32767.0, 0.0, 0.2, 1.0 );
        outColor = vec4(
            float(ivec4CalcValue.r)/32767.0,    //MIN
            float(ivec4CalcValue.g)/32767.0,    //MAX
            float(ivec4CalcValue.b)/32767.0,    // most még csak DEBUG
            float(ivec4CalcValue.a)/32767.0     // most még csak DEBUG
        );
    }
}
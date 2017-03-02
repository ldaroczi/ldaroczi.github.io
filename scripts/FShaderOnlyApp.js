class FShaderOnlyApp {
    constructor(canvas, vshader, fshader) {
        this.vertexShader = vshader;
        this.fragmentShader = fshader;
        this.renderable = false;
        this.createLoggerFunction();
        // this.createShaderPrograms();
        this.log("Start");
        if (!canvas) {
            throw Error("Canvas is unknown.");
        }
        var gl = canvas.getContext("webgl2");
        if (!gl) {
            throw Error("WebGL2 context missing.");
        }
        this.gl = gl;
        this.resizeCanvas(); // Ez lehet, hogy nem kell, mert a canvas-nak már van mérete
        this.defaultColoring();
    }

    setDataSize(pDataSizeX, pDataSizeY, dataGenerator) {
        this.createProgramInfo();
        // this.createPlaneBufferInfo();

        var dataArray = new Int16Array(pDataSizeX * pDataSizeY);
        if (dataGenerator) {
            this.log("Data generation started ... ");
            for (var y = 0; y < pDataSizeY; y++) {
                for (var x = 0; x < pDataSizeX; x++) {
                    var pos = y * pDataSizeX + x;
                    dataArray[pos] = dataGenerator(x, y, pDataSizeX, pDataSizeY);
                }
            }
            this.log("Data generation finished ... ");
        }

        let gl = this.gl;
        let programInfo = this.programInfo;
        let textureData =
            {
                target: gl.TEXTURE_2D,
                internalFormat: gl.R16I,
                format: gl.RED_INTEGER,
                type: gl.SHORT,
                width: pDataSizeX,
                hight: pDataSizeY,
                src: dataArray
            };
        var texture = twgl.createTexture(gl, textureData);
        this.log("Texture generated: " + pDataSizeX + "x" + pDataSizeY + "=" + (pDataSizeX * pDataSizeY));

        gl.useProgram(programInfo.program);
        this.log("Shader programs are selected.");

        // twgl.setBuffersAndAttributes(gl, programInfo, this.planeBufferInfo);
        // this.log("twgl.setBuffersAndAttributes finished");

        let canvas = gl.canvas;

        var uniforms = {
            u_texture: texture,
            dataSize: [pDataSizeX, pDataSizeY],
            resolution: [gl.canvas.width, gl.canvas.height],

            u_minValue: this.coloring.minValue,
            u_minColor: this.coloring.minColor,
            u_colormap: this.coloring.texture,
            u_maxValue: this.coloring.maxValue,
            u_maxColor: this.coloring.maxColor,

            ui_width: canvas.width,
            ui_height: canvas.height,
            uf_x0: -1.0 + 1.0 / canvas.width,
            uf_dx: 2.0 / canvas.width,
            uf_y0: -1.0 + 1.0 / canvas.height,
            uf_dy: 2.0 / canvas.height
        };

        twgl.setUniforms(programInfo, uniforms);
        this.log("Uniforms (texture,dataSize,resolution,coloring) have been set.");

        this.pDataSizeX = pDataSizeX;
        this.pDataSizeY = pDataSizeY;
        this.texture = texture;
        this.page = 0;
        /* Hányadik lapon járunk a feltöltésnél. */
        this.renderable = true;

        this.clearColorBuffer();
    }

    render() {
        if (!this.renderable) {
            return;
        }
        let gl = this.gl;
        let canvas = gl.canvas;

        gl.drawArrays(gl.POINTS, 0, canvas.width * canvas.height);
    }

    demoDataGenerator(x, y, pDataSizeX, pDataSizeY) {
        var result;
        if (
            // Negyedelő pontokban (0, 25, 50, 75, 100%) vízszintes és függőleges "vonal" magas érték formájában
        (x % Math.floor(pDataSizeX / 4) == 0 || x == (pDataSizeX - 1))
        || (y % Math.floor(pDataSizeY / 4) == 0 || y == (pDataSizeY - 1))
        ) {
            result = 32767;
        } else {
            // Egyébként függőleges írányba egyenletes színátmenet 5000-20000 RED
            result = Math.floor(y / pDataSizeY * 15000.0) + 5000;
        }
        return result;
    }

    createLoggerFunction() {
        var logPreTime = 0;
        this.log = function (pMessage) {
            var logNewTime = (new Date()).getTime();
            if (logPreTime == 0) logPreTime = logNewTime;
            console.log("[" + logNewTime + ",+" + (logNewTime - logPreTime) + "]\t" + pMessage);
            logPreTime = logNewTime;
        }
    }

    createProgramInfo() {
        this.programInfo = twgl.createProgramInfo(this.gl, [this.vertexShader, this.fragmentShader]);
    }

    resizeCanvas() {
        var gl = this.gl;
        var canvas = gl.canvas;

        twgl.resizeCanvasToDisplaySize(canvas);
        gl.viewport(0, 0, canvas.width, canvas.height);
    }

    /**
     *
     * @param {ArrayBuffer} arrayBuffer
     */
    processSIMIArrayBufferData(arrayBuffer) {
        try {
            let byteOffset = 0, timestamp, rowIndex, columnIndex, dataLength, levels;
            do {
                timestamp = new Float64Array(arrayBuffer, byteOffset, 1)[0];
                byteOffset += Float64Array.BYTES_PER_ELEMENT;
                rowIndex = new Float64Array(arrayBuffer, byteOffset, 1)[0];
                byteOffset += Float64Array.BYTES_PER_ELEMENT;
                columnIndex = new Float64Array(arrayBuffer, byteOffset, 1)[0];
                byteOffset += Float64Array.BYTES_PER_ELEMENT;
                dataLength = new Float64Array(arrayBuffer, byteOffset, 1)[0];
                byteOffset += Float64Array.BYTES_PER_ELEMENT;
                levels = new Int16Array(arrayBuffer, byteOffset, dataLength);
                byteOffset += Int16Array.BYTES_PER_ELEMENT * dataLength;
                if (dataLength % 4 !== 0) {
                    // tail padding to satisfy the struct word size requirement
                    //(defined by the largest word size of its members)
                    byteOffset += (4 - (dataLength % 4)) * 2;
                }
                // convert to float as described in the device documentation (shortValue / 10)

                this.processArrayBuffer(columnIndex, rowIndex, dataLength, data);
            } while (arrayBuffer.byteLength > byteOffset);
        } catch (e) {
            console.error("Unable to process ArrayBuffer:", e);
        }
    }

    /**
     *
     * @param {number} columnIndex
     * @param {number} rowIndex
     * @param {number} dataLength
     * @param {Int16Array} data
     */
    processArrayBuffer(columnIndex, rowIndex, dataLength, data) {
        let gl = this.gl;

        let oldPage = this.page;
        while ((this.page + 1) * this.pDataSizeY <= rowIndex) {
            this.page++;
        }

        if (this.page !== oldPage) {
            this.clearColorBuffer();
        }

        gl.activeTexture(gl.TEXTURE0);
        let rowIndexInTexture = rowIndex - this.page * this.pDataSizeY;

        gl.texSubImage2D(/*target*/ gl.TEXTURE_2D, /* level */ 0,
            /* xoffset*/ columnIndex, /* yoffset */ rowIndexInTexture,
            /* width */ dataLength, /* height */ 1,
            gl.RED_INTEGER, gl.SHORT, /* source */ data);
    }

    clearColorBuffer() {
        let gl = this.gl;
        gl.clear(gl.COLOR_BUFFER_BIT);
    }

    defaultColoring() {
        this.setColoring(-12000, 'jet', 4000);
    }

    /**
     * Színezés definiálása
     *
     * @param {number} minValue
     * @param {string} colormapName
     * @param {number} nshades
     * @param {number} maxValue
     */
    setColoring(minValue, colormapName, maxValue) {
        let gl = this.gl;

        let nshades = maxValue - minValue + 1;

        let options = {
            colormap: colormapName,   // pick a builtin colormap or add your own
            nshades: nshades,       // how many divisions
            format: 'rgb',     // "hex" or "rgb" or "rgbaString"
            alpha: 255           // set an alpha value or a linear alpha mapping [start, end]
        }
        let cg = SIMIColormap(options);

        let colormapBuffer = new Float32Array(nshades * 3);
        for (let i = 0; i < nshades; i++) {
            let ix = 3 * i;
            colormapBuffer[ix + 0] = cg[i][0] / 255;
            colormapBuffer[ix + 1] = cg[i][1] / 255;
            colormapBuffer[ix + 2] = cg[i][2] / 255;
        }

        let textureData = {
            target: gl.TEXTURE_2D,
            internalFormat: gl.RGB32F,
            format: gl.RGB,
            type: gl.FLOAT,
            width: nshades,
            hight: 1,
            src: colormapBuffer
        };

        let colormapTexture;
        if (this.coloring !== undefined) {
            gl.activeTexture(gl.TEXTURE1);
            colormapTexture = this.coloring.texture;
            twgl.setTextureFromArray(gl, colormapTexture, colormapBuffer, textureData);
            //
            // void gl.texImage2D(target, level, internalformat, width, height, border, format, type, ArrayBufferView srcData, srcOffset);
            // gl.texImage2D(/*target*/ gl.TEXTURE_2D, /* level */ 0,
            //     /* width */ dataLength, /* height */ 1, /* border */ 0,
            //     gl.RED_INTEGER, gl.SHORT, /* source */ this.coloring.texture);
            //
            this.log("Uniforms (coloring) have been set.");
        } else {
            colormapTexture = twgl.createTexture(gl, textureData);
        }

        let minColor = [cg[0][0] / 255, cg[0][1] / 255, cg[0][2] / 255, 1.0];
        let maxColor = [cg[nshades - 1][0] / 255, cg[nshades - 1][1] / 255, cg[nshades - 1][2] / 255, 1.0];

        this.coloring = {
            minValue: minValue,
            minColor: minColor,
            texture: colormapTexture,
            maxValue: maxValue,
            maxColor: maxColor
        }

        if (this.renderable) {
            let uniforms = {
                u_minValue: this.coloring.minValue,
                u_minColor: this.coloring.minColor,
                u_maxValue: this.coloring.maxValue,
                u_maxColor: this.coloring.maxColor
            }
            twgl.setUniforms(this.programInfo, uniforms);
        }
    }
}


function SemigrafxVM(rootNode, program) {
    rootNode.innerHTML = '';

    rootNode.setAttribute('style',
        'position: relative; width: 512px; height: 512px; background-color: white;');

    var tileNodes = [];
    initTileNodes();

    function initTileNodes() {
        for (var row = 0; row < 32; row++) {
            for (var col = 0; col < 32; col++) {
                var tileNode = document.createElement('div');

                tileNode.dataset.index = tileNodes.length;
                tileNode.dataset.row = row;
                tileNode.dataset.col = col;
                
                tileNode.style.position = 'absolute';
                tileNode.style.top = '' + row*16 + 'px';
                tileNode.style.left = '' + col*16 + 'px';
                tileNode.style.width = '16px';
                tileNode.style.height = '16px';
                tileNode.style.backgroundImage = 'url(ascii-dos-8x8.png)';
                tileNode.style.backgroundRepeat = 'no-repeat';
                tileNode.style.backgroundPositionX = '0px';
                tileNode.style.backgroundPositionY = '0px';

                rootNode.appendChild(tileNode);
                tileNodes.push(tileNode);
            }
        }
    }

    var screenBuffer = [];
    var buffers = [];

    function bufferAt(idx) {
        if (!buffers[idx]) {
            throw new Error('bad buffer: ' + idx);
        }
        return buffers[idx];
    }

    var builtins = Object.create(null);

    builtins.buffer = function(size) {
        if (size < 1 || size > 1024) {
            throw new Error('buffer must have size between 1 and 1024');
        }

        if (buffers.length >= 32) {
            throw new Error('cannot have more than 32 buffers');
        }

        var buffer = new Array(size);
        for (var i = 0; i < size; i++) {
            buffer[i] = 0;
        }

        buffers.push(buffer);

        return buffers.length - 1;
    };
    
    builtins.size = function(buffer) {
        return bufferAt(buffer).length;
    };

    builtins.push = function(buffer, value) {
        buffer = bufferAt(buffer);
        if (buffer.length >= 1024) {
            throw new Error('buffer cannot grow beyond 1024 elements');
        }
        buffer.push(value);
        return value;
    };

    builtins.pop = function(buffer) {
        buffer = bufferAt(buffer);
        if (buffer.length === 0) {
            throw new Error('pop on empty buffer');
        }
        return buffer.pop();
    };

    builtins.get = function(buffer, idx) {
        buffer = bufferAt(buffer);
        if (idx < 0 || idx >= buffer.length) {
            throw new Error('get out of bounds');
        }
        return buffer[idx];
    };

    builtins.set = function(buffer, idx, value) {
        buffer = bufferAt(buffer);
        if (idx < 0 || idx >= buffer.length) {
            throw new Error('set out of bounds ' + buffer + ' ' + idx);
        }
        return buffer[idx] = value;
    };

    builtins.screen = function(buffer) {
        screenBuffer = bufferAt(buffer);
        return 0;
    };

    builtins.eq = function(x, y) {
        return x === y ? 1 : 0;
    };

    builtins.ne = function(x, y) {
        return x !== y ? 1 : 0;
    };

    builtins.gt = function(x, y) {
        return x > y ? 1 : 0;
    };

    builtins.lt = function(x, y) {
        return x < y ? 1 : 0;
    };

    builtins.gte = function(x, y) {
        return x >= y ? 1 : 0;
    };

    builtins.lte = function(x, y) {
        return x <= y ? 1 : 0;
    };

    builtins.add = function() {
        var sum = 0;
        for (var i = 0; i < arguments.length; i++) {
            sum += arguments[i];
        }
        return sum;
    };

    builtins.sub = function() {
        var dif = arguments[0] || 0;
        for (var i = 1; i < arguments.length; i++) {
            dif -= arguments[i];
        }
        return dif;
    };
    builtins.mul = function(x, y) {
        return (x * y) | 0;
    };
    builtins.div = function(x, y) {
        return ~~(x/y);
    };
    builtins.mod = function(x, y) {
        return x % y;
    };

    builtins.random = function(max) {
        return (Math.random()*max) | 0;
    };

    var instance = program(builtins);
    instance.init();
    refresh();

    function refresh() {
        var code, tile, x, y;
        for (var i = 0; i < 1024; i++) {
            code = screenBuffer[i] || 0;
            x = (code % 16) * -16;
            y = (~~(code / 16)) * -16;
            tile = tileNodes[i];
            tile.style.backgroundPositionX = x.toString() + 'px';
            tile.style.backgroundPositionY = y.toString() + 'px';
        }
    }

    rootNode.onmousedown = function(event) {
        if (instance.mousedown) {
            instance.mousedown(event.target.dataset.row, event.target.dataset.col, event.shiftKey, event.altKey);
            refresh();
        }
        return false;
    };

    document.onkeydown = function(event) {
        if (event.metaKey || event.ctrlKey) return true;
        if (event.keyCode != 32 && (event.keyCode < 65 || event.keyCode > 90)) return true;
        if (instance.keydown) {
            instance.keydown(event.keyCode, event.shiftKey, event.altKey);
            refresh();
        }
        return false;
    };
}

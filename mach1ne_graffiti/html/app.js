const RESOURCE = GetParentResourceName();
const canvas = document.getElementById('graffitiCanvas');
const ctx    = canvas.getContext('2d');

// Sæt canvas til skærmens faktiske opløsning så koordinater er præcise
canvas.width  = window.innerWidth  || 1920;
canvas.height = window.innerHeight || 1080;

// ── State ──────────────────────────────────────────────
let drawing      = false;
let erasing      = false;
let lastX        = 0, lastY = 0;
let currentColor = '#e63946';
let currentSize  = 14;
let pressure     = 1.0;   // simulated distance pressure (0.3–1.0)

// Stroke-based undo/redo
let undoStack = [];   // each entry = ImageData snapshot before stroke
let redoStack = [];
const MAX_UNDO = 20;

function fetchNUI(event, body = {}) {
    return fetch(`https://${RESOURCE}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    }).then(r => r.json()).catch(() => null);
}

// ── Undo / Redo ─────────────────────────────────────────
function saveSnapshot() {
    undoStack.push(ctx.getImageData(0, 0, canvas.width, canvas.height));
    if (undoStack.length > MAX_UNDO) undoStack.shift();
    redoStack = [];
}

function undo() {
    if (!undoStack.length) return;
    redoStack.push(ctx.getImageData(0, 0, canvas.width, canvas.height));
    ctx.putImageData(undoStack.pop(), 0, 0);
}

function redo() {
    if (!redoStack.length) return;
    undoStack.push(ctx.getImageData(0, 0, canvas.width, canvas.height));
    ctx.putImageData(redoStack.pop(), 0, 0);
}

// ── Spray paint simulation ──────────────────────────────
function sprayDot(x, y, color, size, alpha) {
    const r       = size / 2;
    const spread  = r * (1 + (1 - pressure) * 1.5);  // more spread at low pressure
    const density = Math.max(6, Math.floor(size * pressure * 4));

    ctx.save();
    ctx.globalAlpha = alpha * pressure;

    if (erasing) {
        // Eraser: draw white with hard edge
        ctx.globalCompositeOperation = 'destination-out';
        ctx.fillStyle = 'rgba(255,255,255,1)';
        for (let i = 0; i < density; i++) {
            const angle  = Math.random() * Math.PI * 2;
            const radius = Math.random() * spread;
            ctx.beginPath();
            ctx.arc(x + Math.cos(angle) * radius, y + Math.sin(angle) * radius, r * 0.3, 0, Math.PI * 2);
            ctx.fill();
        }
    } else {
        // Spray: radial gradient dots scattered in spread radius
        for (let i = 0; i < density; i++) {
            const angle  = Math.random() * Math.PI * 2;
            const radius = Math.random() * spread;
            const px     = x + Math.cos(angle) * radius;
            const py     = y + Math.sin(angle) * radius;
            const dr     = r * (0.15 + Math.random() * 0.25);
            const grad   = ctx.createRadialGradient(px, py, 0, px, py, dr);
            grad.addColorStop(0,   color);
            grad.addColorStop(0.6, color + 'cc');
            grad.addColorStop(1,   color + '00');
            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.arc(px, py, dr, 0, Math.PI * 2);
            ctx.fill();
        }
    }
    ctx.restore();
}

function sprayLine(x0, y0, x1, y1) {
    const dx    = x1 - x0, dy = y1 - y0;
    const dist  = Math.sqrt(dx * dx + dy * dy);
    const steps = Math.max(1, Math.ceil(dist / (currentSize * 0.25)));
    for (let i = 0; i <= steps; i++) {
        const t = i / steps;
        sprayDot(x0 + dx * t, y0 + dy * t, currentColor, currentSize, 0.85);
    }
}

function getPos(e) {
    const rect   = canvas.getBoundingClientRect();
    const scaleX = canvas.width  / rect.width;
    const scaleY = canvas.height / rect.height;
    return {
        x: (e.clientX - rect.left) * scaleX,
        y: (e.clientY - rect.top)  * scaleY,
    };
}

// ── Canvas events ───────────────────────────────────────
canvas.addEventListener('mousedown', (e) => {
    saveSnapshot();
    drawing = true;
    const p = getPos(e);
    lastX = p.x; lastY = p.y;
    sprayDot(p.x, p.y, currentColor, currentSize, 0.85);
});

canvas.addEventListener('mousemove', (e) => {
    if (!drawing) return;
    const p = getPos(e);
    sprayLine(lastX, lastY, p.x, p.y);
    lastX = p.x; lastY = p.y;
});

canvas.addEventListener('mouseup',    () => { drawing = false; });
canvas.addEventListener('mouseleave', () => { drawing = false; });

// Scroll = change brush size
canvas.addEventListener('wheel', (e) => {
    e.preventDefault();
    currentSize = Math.max(2, Math.min(60, currentSize - Math.sign(e.deltaY) * 2));
    updateSizeIndicator();
}, { passive: false });

// ── Toolbar builders ────────────────────────────────────
function buildColors(colors) {
    const container = document.getElementById('colors');
    container.innerHTML = '';
    colors.forEach((c, i) => {
        const sw = document.createElement('div');
        sw.className = 'color-swatch' + (i === 0 ? ' active' : '');
        sw.style.background = c.hex;
        sw.title = c.name;
        sw.dataset.active = (i === 0) ? '1' : '0';
        sw.addEventListener('click', () => {
            document.querySelectorAll('.color-swatch').forEach(s => { s.classList.remove('active'); s.dataset.active = '0'; });
            sw.classList.add('active');
            sw.dataset.active = '1';
            currentColor = c.hex;
            setEraserMode(false);
        });
        container.appendChild(sw);
    });
}

function updateSizeIndicator() {
    const el = document.getElementById('sizeValue');
    if (el) el.textContent = currentSize;
}

function setEraserMode(on) {
    erasing = on;
    document.getElementById('btnEraser').classList.toggle('active', on);
    document.getElementById('app').classList.toggle('eraser-mode', on);
    document.getElementById('statusLabel').textContent = on ? 'VISKER' : 'SPRAY';
    document.getElementById('statusIcon').textContent  = on ? '◈' : '✦';
    if (!on) {
        document.querySelectorAll('.color-swatch').forEach(s => {
            if (s.dataset.active === '1') s.classList.add('active');
        });
    }
}

function buildSizes(sizes) {
    const container = document.getElementById('sizes');
    container.innerHTML = '';
    sizes.forEach((sz, i) => {
        const dot = document.createElement('div');
        dot.className = 'size-dot' + (i === 2 ? ' active' : '');
        dot.style.width  = Math.min(sz + 12, 44) + 'px';
        dot.style.height = Math.min(sz + 12, 44) + 'px';
        dot.title = sz + 'px';
        dot.addEventListener('click', () => {
            document.querySelectorAll('.size-dot').forEach(d => d.classList.remove('active'));
            dot.classList.add('active');
            currentSize = sz;
            updateSizeIndicator();
        });
        container.appendChild(dot);
    });
}

function clearCanvas() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
}

// ── Button listeners ────────────────────────────────────
document.getElementById('btnEraser').addEventListener('click', () => setEraserMode(!erasing));

document.getElementById('btnUndo').addEventListener('click', undo);
document.getElementById('btnRedo').addEventListener('click', redo);

document.getElementById('btnClear').addEventListener('click', () => {
    saveSnapshot();
    clearCanvas();
});

document.getElementById('btnSave').addEventListener('click', () => {
    // Skaler ned til 512x512 PNG for at holde datastørrelsen lille
    const exp = document.createElement('canvas');
    exp.width  = 512;
    exp.height = 512;
    const ectx = exp.getContext('2d');
    ectx.drawImage(canvas, 0, 0, 512, 512);
    const dataURL = exp.toDataURL('image/png');
    fetchNUI('save', { image: dataURL });
});

document.getElementById('btnCancel').addEventListener('click', () => {
    fetchNUI('cancel', {});
});

// ── NUI messages ────────────────────────────────────────
window.addEventListener('message', (e) => {
    const { action, data } = e.data;
    if (action === 'open') {
        undoStack = []; redoStack = [];
        erasing = false;
        currentColor = (data?.colors?.[0]?.hex) || '#e63946';
        currentSize  = (data?.sizes?.[2])        || 14;
        buildColors(data?.colors || []);
        buildSizes(data?.sizes   || [4, 8, 14, 22, 32]);
        clearCanvas();
        updateSizeIndicator();
        document.getElementById('app').style.display = 'flex';
    } else if (action === 'close') {
        document.getElementById('app').style.display = 'none';
        clearCanvas();
        undoStack = []; redoStack = [];
    }
});

// ── Keyboard shortcuts ──────────────────────────────────
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape')                         fetchNUI('cancel', {});
    if ((e.ctrlKey || e.metaKey) && e.key === 'z')  undo();
    if ((e.ctrlKey || e.metaKey) && e.key === 'y')  redo();
    if (e.key === 'e' || e.key === 'E') setEraserMode(!erasing);
});

clearCanvas();

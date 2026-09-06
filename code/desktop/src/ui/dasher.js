// The zooming navigator's front-end: renders dasherModel.js's boxes onto a
// canvas at 60fps and wires the slider, hold-to-go/back, and the two settings
// that matter (speed, and how strongly prediction sizes the targets).
//
// The slider is the whole input. One continuous 1D axis is what the phone app
// already calibrates for — code/app/lib/runtime/task_spec.dart's
// TaskShape.continuous, driven by a joystick — so anything drivable here is
// drivable from the phone without a second control channel.

import {
  buildNavigationTree, childrenOf, DasherEngine, MAX_Y, ORIGIN_Y, SPEED_PRESETS,
} from '/dasherModel.js';

const KIND_COLOURS = {
  feature: { fill: '#2f4a2c', text: '#dff0d8' },
  group: { fill: '#4a3f22', text: '#f0e6c8' },
  letter: { fill: '#263d4a', text: '#d8ecf5' },
  commit: { fill: '#5d6b2c', text: '#f4f7dd' },
  back: { fill: '#3a3327', text: '#c9c0aa' },
};

export class DasherView {
  /**
   * @param root - the container element.
   * @param deps.act    - ({ feature, action, value }) => Promise, the real dispatch.
   * @param deps.onLog  - (event) => void, for the inspector's event log.
   */
  constructor(root, { act, onLog = () => {} }) {
    this.container = root;
    this.act = act;
    this.onLog = onLog;
    this.engine = null;
    this.aux = null;
    this.running = false;
    this.direction = 0;
    this.buffer = '';
    this.trail = [];
    this.build();
  }

  build() {
    this.container.innerHTML = `
      <div class="dasher-head">
        <span class="dasher-path" id="dasher-path">—</span>
        <label class="toggle"><input type="checkbox" id="dasher-auto" /> auto-advance</label>
        <label class="toggle">speed
          <select id="dasher-speed">
            <option value="beginner">beginner</option>
            <option value="intermediate" selected>intermediate</option>
            <option value="advanced">advanced</option>
          </select>
        </label>
        <label class="toggle" title="Low = the predicted option gets a much bigger target. High = every option nearer equal.">
          prediction
          <input type="range" id="dasher-temp" min="0.4" max="4" step="0.1" value="1.2" />
        </label>
      </div>
      <div class="dasher-stage">
        <canvas id="dasher-canvas"></canvas>
        <input type="range" id="dasher-slider" class="dasher-slider"
               min="0" max="${MAX_Y}" step="1" value="${ORIGIN_Y}"
               aria-label="Steer through the options" />
      </div>
      <div class="dasher-controls">
        <button type="button" id="dasher-back" class="ghost">◀ hold to back out</button>
        <button type="button" id="dasher-go">hold to go ▶</button>
        <span class="dasher-buffer" id="dasher-buffer"></span>
      </div>`;

    this.canvas = this.container.querySelector('#dasher-canvas');
    this.ctx = this.canvas.getContext('2d');
    this.slider = this.container.querySelector('#dasher-slider');
    this.pathLabel = this.container.querySelector('#dasher-path');
    this.bufferLabel = this.container.querySelector('#dasher-buffer');
    this.speed = this.container.querySelector('#dasher-speed');
    this.temperature = this.container.querySelector('#dasher-temp');
    this.auto = this.container.querySelector('#dasher-auto');

    const go = this.container.querySelector('#dasher-go');
    const back = this.container.querySelector('#dasher-back');
    const hold = (el, dir) => {
      const start = (e) => { e.preventDefault(); this.direction = dir; el.classList.add('held'); };
      const stop = () => { this.direction = 0; el.classList.remove('held'); };
      el.addEventListener('pointerdown', start);
      el.addEventListener('pointerup', stop);
      el.addEventListener('pointerleave', stop);
      el.addEventListener('pointercancel', stop);
    };
    hold(go, 1);
    hold(back, -1);

    this.speed.onchange = () => { if (this.engine) this.engine.speed = this.speed.value; };
    this.temperature.onchange = () => this.rebuild();

    // Steering with the mouse as well as the slider: the canvas is the same
    // axis, and it makes the thing demonstrable without reaching for a control.
    this.canvas.addEventListener('pointermove', (e) => {
      const rect = this.canvas.getBoundingClientRect();
      this.slider.value = String(((e.clientY - rect.top) / rect.height) * MAX_Y);
    });
    this.canvas.addEventListener('pointerdown', (e) => { e.preventDefault(); this.direction = 1; });
    window.addEventListener('pointerup', () => {
      if (!go.classList.contains('held') && !back.classList.contains('held')) this.direction = 0;
    });

    // A hidden tab gets no animation frames at all, so motion simply stops.
    // Releasing the direction on the way out means returning to the tab does
    // not resume a hold that was started minutes ago.
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) this.direction = 0;
    });

    this.resize = () => {
      const ratio = window.devicePixelRatio || 1;
      const { width, height } = this.canvas.getBoundingClientRect();
      this.canvas.width = Math.max(1, Math.round(width * ratio));
      this.canvas.height = Math.max(1, Math.round(height * ratio));
      this.ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
      this.cssSize = { width, height };
    };
    window.addEventListener('resize', this.resize);
  }

  /**
   * Point the navigator at a new scan — but not while someone is part-way into
   * a branch. A scan can land at any moment (the watcher fires on any real
   * page change), and rebuilding mid-steer swaps the tree under the user and
   * discards a half-spelled word. Hold it until they are back at the top.
   */
  setScan(aux) {
    if (this.engine && this.engine.ancestors.length > 0) {
      this.pending = aux;
      return;
    }
    this.pending = null;
    this.aux = aux;
    this.rebuild();
  }

  rebuild() {
    if (!this.aux) return;
    const wasSpelling = this.engine?.root?.kind === 'letter';
    const tree = buildNavigationTree(this.aux, {
      onAct: (request) => this.dispatch(request),
      onText: (buffer) => { this.buffer = buffer; this.bufferLabel.textContent = buffer ? '“' + buffer + '”' : ''; },
    }, { temperature: Number(this.temperature.value) });

    if (this.engine) this.engine.setRoot(tree);
    else {
      this.engine = new DasherEngine(tree, { speed: this.speed.value });
      this.engine.onCommit = (event) => this.commit(event);
    }
    this.engine.speed = this.speed.value;
    if (!wasSpelling) { this.buffer = ''; this.bufferLabel.textContent = ''; }
    this.trail = [];
  }

  commit({ node, kind }) {
    if (kind === 'back') { this.trail.pop(); return; }
    if (kind === 'letter') return; // the buffer readout already shows these
    // An action rewinds the engine to the top, so the breadcrumb has to reset
    // with it — otherwise the readout keeps naming a branch nobody is in.
    if (kind === 'commit') { this.trail = []; return; }
    this.trail.push(node.label);
    if (this.trail.length > 4) this.trail.shift();
  }

  async dispatch({ feature, action, value }) {
    this.onLog({ type: 'dasher', message: action + ' ' + (feature.label ?? feature.role), at: Date.now() });
    try {
      await this.act({
        ref: feature.ref,
        signature: feature.signature,
        identity: feature.identity,
        action,
        value,
      });
    } catch (err) {
      this.onLog({ type: 'error', message: err.message, at: Date.now() });
    }
  }

  start() {
    if (this.running) return;
    this.running = true;
    this.resize();
    const frame = () => {
      if (!this.running) return;
      this.tick();
      this.raf = requestAnimationFrame(frame);
    };
    this.raf = requestAnimationFrame(frame);
  }

  stop() {
    this.running = false;
    this.direction = 0;
    if (this.raf) cancelAnimationFrame(this.raf);
  }

  tick() {
    if (!this.engine) return;
    if (this.pending && this.engine.ancestors.length === 0) {
      const aux = this.pending;
      this.pending = null;
      this.aux = aux;
      this.rebuild();
    }
    const direction = this.direction || (this.auto.checked ? 1 : 0);
    if (direction !== 0) this.engine.step(Number(this.slider.value), direction);
    this.draw();
  }

  draw() {
    const { ctx } = this;
    const { width, height } = this.cssSize ?? this.canvas.getBoundingClientRect();
    if (!width || !height) return;

    ctx.clearRect(0, 0, width, height);
    ctx.fillStyle = '#12140e';
    ctx.fillRect(0, 0, width, height);

    const boxes = this.engine.layout();
    const toY = (v) => (v / MAX_Y) * height;
    // Depth reads left-to-right, the way Dasher nests columns: a child starts
    // where its parent ends, so the zoom direction is visible as a direction.
    const column = Math.max(96, width / 5);
    const path = this.engine.crosshairPath(boxes);
    const onCrosshair = new Set(path.map(box => box.node.id));

    for (const box of boxes) {
      const y = toY(box.min);
      const h = Math.max(toY(box.max) - y, 0);
      const x = box.depth * column;
      const w = width - x;
      if (h < 1) continue;

      const colours = KIND_COLOURS[box.node.kind] ?? KIND_COLOURS.feature;
      const live = onCrosshair.has(box.node.id);
      ctx.fillStyle = colours.fill;
      ctx.strokeStyle = live ? '#dfe4bd' : 'rgba(0,0,0,0.45)';
      ctx.lineWidth = live ? 2 : 1;
      ctx.beginPath();
      ctx.roundRect(x, y, w, Math.max(h - 1, 1), 4);
      ctx.fill();
      ctx.stroke();
      ctx.lineWidth = 1;

      // A label lives in the strip its own children have not covered yet —
      // children are drawn after their parent and would otherwise paint over
      // it, which is what made every box read as a truncated word.
      const strip = column - 18;
      if (h >= 13 && strip > 24) {
        const size = Math.min(Math.max(h * 0.4, 11), 20);
        ctx.fillStyle = colours.text;
        ctx.font = (live ? '700 ' : '600 ') + size + 'px ui-sans-serif, system-ui, sans-serif';
        ctx.textBaseline = 'middle';
        const label = box.node.labelOf ? box.node.labelOf() : box.node.label;
        ctx.fillText(ellipsize(ctx, label, strip), x + 10, y + h / 2);
      }
    }

    // Crosshair: what you are about to enter is whatever sits on this line.
    const mid = height / 2;
    ctx.strokeStyle = '#dfe4bd';
    ctx.lineWidth = 1;
    ctx.setLineDash([5, 4]);
    ctx.beginPath();
    ctx.moveTo(0, mid);
    ctx.lineTo(width, mid);
    ctx.stroke();
    ctx.setLineDash([]);

    // Where the slider is pointing — the point that gets pulled to the crosshair.
    const aim = toY(Number(this.slider.value));
    ctx.fillStyle = '#e0b96a';
    ctx.beginPath();
    ctx.moveTo(width - 1, aim);
    ctx.lineTo(width - 13, aim - 7);
    ctx.lineTo(width - 13, aim + 7);
    ctx.closePath();
    ctx.fill();

    const here = [...this.trail, path[0]?.node.label].filter(Boolean);
    this.pathLabel.textContent = here.length ? here.join(' › ') : '—';
  }
}

/** Trim a label to fit `maxWidth`, with an ellipsis if it had to be cut. */
function ellipsize(ctx, text, maxWidth) {
  if (ctx.measureText(text).width <= maxWidth) return text;
  let low = 0;
  let high = text.length;
  while (low < high) {
    const mid = (low + high + 1) >> 1;
    if (ctx.measureText(text.slice(0, mid) + '…').width <= maxWidth) low = mid;
    else high = mid - 1;
  }
  return low > 0 ? text.slice(0, low) + '…' : '';
}

export { SPEED_PRESETS, childrenOf };

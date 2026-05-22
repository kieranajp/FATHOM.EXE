/**
 * Vector Buccaneer - Web Audio Synth Engine
 * Procedurally generates retro 8-bit sound effects and ambient noises without external assets.
 */

const AudioEngine = {
    ctx: null,
    initialized: false,
    ambientWind: null,
    ambientWaves: null,
    masterGain: null,

    // Initialize the Web Audio Context (must be triggered by a user interaction)
    init: function() {
        if (this.initialized) return;

        const AudioContextClass = window.AudioContext || window.webkitAudioContext;
        if (!AudioContextClass) {
            console.warn("Web Audio API is not supported in this browser.");
            return;
        }

        try {
            this.ctx = new AudioContextClass();
            
            // Master gain to keep sounds comfortable
            this.masterGain = this.ctx.createGain();
            this.masterGain.gain.value = 0.6; // Moderate overall volume
            this.masterGain.connect(this.ctx.destination);

            // Initialize ambient channels
            this.setupAmbientWind();
            this.setupAmbientWaves();

            this.initialized = true;
            console.log("Web Audio Engine Initialized.");
        } catch (e) {
            console.error("Failed to initialize Audio Engine:", e);
        }
    },

    // Ensure audio context is running (fixes browser autoplay restrictions)
    resume: function() {
        if (this.ctx && this.ctx.state === 'suspended') {
            this.ctx.resume();
        }
    },

    // White Noise generator for wind & sea rumble
    createNoiseBuffer: function() {
        const bufferSize = this.ctx.sampleRate * 2; // 2 seconds of noise
        const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < bufferSize; i++) {
            data[i] = Math.random() * 2 - 1;
        }
        return buffer;
    },

    // Procedural Wind Synth
    setupAmbientWind: function() {
        const noise = this.ctx.createBufferSource();
        noise.buffer = this.createNoiseBuffer();
        noise.loop = true;

        // Bandpass filter to make noise sound like howling wind
        const bandpass = this.ctx.createBiquadFilter();
        bandpass.type = 'bandpass';
        bandpass.frequency.value = 250; // Starting frequency (Hz)
        bandpass.Q.value = 3.0; // Sharpness

        // Wind volume control
        const gainNode = this.ctx.createGain();
        gainNode.gain.value = 0.04;

        // An oscillator to dynamically modulate filter frequency (simulates gusts)
        const gustLfo = this.ctx.createOscillator();
        gustLfo.type = 'sine';
        gustLfo.frequency.value = 0.08; // Super slow gusts (12.5s cycle)

        const gustGain = this.ctx.createGain();
        gustGain.gain.value = 100; // Modulate frequency by +/- 100Hz

        gustLfo.connect(gustGain);
        gustGain.connect(bandpass.frequency);

        // Connect nodes
        noise.connect(bandpass);
        bandpass.connect(gainNode);
        gainNode.connect(this.masterGain);

        // Start
        noise.start(0);
        gustLfo.start(0);

        this.ambientWind = { source: noise, filter: bandpass, gain: gainNode, lfo: gustLfo };
    },

    // Procedural Ocean Wave Synth
    setupAmbientWaves: function() {
        const noise = this.ctx.createBufferSource();
        noise.buffer = this.createNoiseBuffer();
        noise.loop = true;

        // Lowpass filter for deep sea rumble
        const lowpass = this.ctx.createBiquadFilter();
        lowpass.type = 'lowpass';
        lowpass.frequency.value = 80;

        // Wave volume control
        const gainNode = this.ctx.createGain();
        gainNode.gain.value = 0.08;

        // Slow LFO to swell wave volume (simulates crashing waves)
        const swellLfo = this.ctx.createOscillator();
        swellLfo.type = 'sine';
        swellLfo.frequency.value = 0.2; // 5-second wave cycle

        const swellGain = this.ctx.createGain();
        swellGain.gain.value = 0.04; // Vol swelling bounds

        swellLfo.connect(swellGain);
        swellGain.connect(gainNode.gain);

        // Connect nodes
        noise.connect(lowpass);
        lowpass.connect(gainNode);
        gainNode.connect(this.masterGain);

        noise.start(0);
        swellLfo.start(0);

        this.ambientWaves = { source: noise, filter: lowpass, gain: gainNode, lfo: swellLfo };
    },

    // Set wind sound frequency depending on ship speed
    updateWindFrequency: function(speedPercent) {
        if (!this.initialized || !this.ambientWind) return;
        
        // Faster sailing increases wind whistle
        const baseFreq = 200 + (speedPercent * 180);
        this.ambientWind.filter.frequency.setValueAtTime(baseFreq, this.ctx.currentTime);
        this.ambientWind.gain.gain.setValueAtTime(0.04 + (speedPercent * 0.05), this.ctx.currentTime);
    },

    // Play a retro UI beep/clicks
    playBeep: function(freq = 800, duration = 0.05) {
        if (!this.initialized) return;
        this.resume();

        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, this.ctx.currentTime);

        gain.gain.setValueAtTime(0.15, this.ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + duration);

        osc.connect(gain);
        gain.connect(this.masterGain);

        osc.start();
        osc.stop(this.ctx.currentTime + duration);
    },

    // Play a delightful chiptune port docking melody (jingle)
    playDockJingle: function() {
        if (!this.initialized) return;
        this.resume();

        const now = this.ctx.currentTime;
        const notes = [261.63, 329.63, 392.00, 523.25, 392.00, 523.25, 659.25]; // C4, E4, G4, C5, G4, C5, E5 arpeggio
        const tempo = 0.12; // Time between notes

        notes.forEach((freq, idx) => {
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();

            osc.type = 'triangle'; // Smooth retro sound
            osc.frequency.setValueAtTime(freq, now + idx * tempo);

            gain.gain.setValueAtTime(0, now + idx * tempo);
            gain.gain.linearRampToValueAtTime(0.18, now + idx * tempo + 0.02);
            gain.gain.exponentialRampToValueAtTime(0.001, now + idx * tempo + tempo * 1.5);

            osc.connect(gain);
            gain.connect(this.masterGain);

            osc.start(now + idx * tempo);
            osc.stop(now + idx * tempo + tempo * 1.8);
        });
    },

    // Play an 8-bit coin cash register sound
    playCoin: function() {
        if (!this.initialized) return;
        this.resume();

        const now = this.ctx.currentTime;
        const notes = [987.77, 1318.51]; // B5 then E6 (classic Mario-like cash sound)
        
        notes.forEach((freq, idx) => {
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();

            osc.type = 'square';
            osc.frequency.setValueAtTime(freq, now + idx * 0.08);

            gain.gain.setValueAtTime(0.12, now + idx * 0.08);
            gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.08 + 0.15);

            osc.connect(gain);
            gain.connect(this.masterGain);

            osc.start(now + idx * 0.08);
            osc.stop(now + idx * 0.08 + 0.2);
        });
    },

    // Play retro laser/cannon fire sweep
    playShoot: function() {
        if (!this.initialized) return;
        this.resume();

        const now = this.ctx.currentTime;
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'sawtooth';
        // Fast pitch slide down (chirp)
        osc.frequency.setValueAtTime(280, now);
        osc.frequency.exponentialRampToValueAtTime(60, now + 0.35);

        gain.gain.setValueAtTime(0.2, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);

        osc.connect(gain);
        gain.connect(this.masterGain);

        osc.start();
        osc.stop(now + 0.35);
    },

    // Play retro explosion (White noise burst + pitch slide down)
    playExplosion: function() {
        if (!this.initialized) return;
        this.resume();

        const now = this.ctx.currentTime;
        
        // 1. Noise source for gravel/debris
        const noise = this.ctx.createBufferSource();
        noise.buffer = this.createNoiseBuffer();
        
        const noiseFilter = this.ctx.createBiquadFilter();
        noiseFilter.type = 'lowpass';
        noiseFilter.frequency.setValueAtTime(600, now);
        noiseFilter.frequency.exponentialRampToValueAtTime(80, now + 0.8);

        const noiseGain = this.ctx.createGain();
        noiseGain.gain.setValueAtTime(0.25, now);
        noiseGain.gain.exponentialRampToValueAtTime(0.001, now + 0.8);

        noise.connect(noiseFilter);
        noiseFilter.connect(noiseGain);
        noiseGain.connect(this.masterGain);

        // 2. Low sine wave drop for sub impact
        const subOsc = this.ctx.createOscillator();
        const subGain = this.ctx.createGain();

        subOsc.type = 'sine';
        subOsc.frequency.setValueAtTime(100, now);
        subOsc.frequency.exponentialRampToValueAtTime(10, now + 0.6);

        subGain.gain.setValueAtTime(0.3, now);
        subGain.gain.exponentialRampToValueAtTime(0.001, now + 0.6);

        subOsc.connect(subGain);
        subGain.connect(this.masterGain);

        // Trigger both
        noise.start(now);
        noise.stop(now + 0.8);
        subOsc.start(now);
        subOsc.stop(now + 0.6);
    },

    // Play retro tankard clink for buying a drink in the tavern
    playClink: function() {
        if (!this.initialized) return;
        this.resume();

        const now = this.ctx.currentTime;
        const freqs = [1480, 1850];
        
        freqs.forEach((freq, idx) => {
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();

            osc.type = 'triangle';
            osc.frequency.setValueAtTime(freq, now);

            gain.gain.setValueAtTime(0.12, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.3);

            osc.connect(gain);
            gain.connect(this.masterGain);

            osc.start(now);
            osc.stop(now + 0.3);
        });
    },

    // Play a repeating security klaxon alarm pitch oscillation for Port Authority enforcers
    playAlarmSiren: function() {
        if (!this.initialized) return;
        this.resume();

        const now = this.ctx.currentTime;
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'sawtooth';
        // Pitch oscillates rapidly up and down
        osc.frequency.setValueAtTime(440, now);
        osc.frequency.linearRampToValueAtTime(880, now + 0.25);
        osc.frequency.linearRampToValueAtTime(440, now + 0.5);

        gain.gain.setValueAtTime(0.08, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.5);

        osc.connect(gain);
        gain.connect(this.masterGain);

        osc.start(now);
        osc.stop(now + 0.5);
    },

    // Play a retro deep water splash sound for cannonballs that miss hulls
    playSplash: function() {
        if (!this.initialized) return;
        this.resume();

        const now = this.ctx.currentTime;
        const noise = this.ctx.createBufferSource();
        noise.buffer = this.createNoiseBuffer();

        const filter = this.ctx.createBiquadFilter();
        filter.type = 'lowpass';
        filter.frequency.setValueAtTime(250, now);
        filter.frequency.exponentialRampToValueAtTime(30, now + 0.55);

        const gain = this.ctx.createGain();
        gain.gain.setValueAtTime(0.25, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.55);

        noise.connect(filter);
        filter.connect(gain);
        gain.connect(this.masterGain);

        noise.start(now);
        noise.stop(now + 0.55);
    },

    // Play a retro traveling sweep/sonar ping proportional to transit progress
    playTravelSweep: function(progressPct) {
        if (!this.initialized) return;
        this.resume();

        const now = this.ctx.currentTime;
        const baseFreq = 400 + progressPct * 800;

        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'sine';
        osc.frequency.setValueAtTime(baseFreq, now);
        osc.frequency.exponentialRampToValueAtTime(baseFreq * 1.5, now + 0.15);

        gain.gain.setValueAtTime(0.08, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);

        osc.connect(gain);
        gain.connect(this.masterGain);

        osc.start(now);
        osc.stop(now + 0.15);
    }
};

// Expose audio globally for browsers
if (typeof window !== 'undefined') {
    window.AudioEngine = AudioEngine;
}

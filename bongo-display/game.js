class BongoGame {
    constructor() {
        this.socket = null;
        this.isPlaying = false;
        this.gameState = {
            songTitle: '',
            bpm: 0,
            beatMap: [],
            score: 0,
            combo: 0,
            startTime: 0, // When the song actually started (Date.now())
            serverPlaybackTime: 0, // Last received playback time from server
            lastSyncTime: 0, // When we received the last sync
        };
        
        // Configuration
        this.noteSpeed = 500; // Pixels per second (scroll speed)
        this.hitZoneY = 0; // Calculated in resize
        this.lookaheadTime = 2.0; // Seconds to spawn notes early
        
        // Runtime tracking
        this.visibleNotes = []; // DOM elements and data
        this.nextNoteIndex = 0;
        
        this.elements = {
            screens: {
                connection: document.getElementById('connection-screen'),
                game: document.getElementById('game-screen'),
                results: document.getElementById('results-screen')
            },
            status: document.getElementById('connection-status'),
            wsUrl: document.getElementById('ws-url'),
            connectBtn: document.getElementById('connect-btn'),
            debugBtn: document.getElementById('debug-btn'),
            score: document.getElementById('score-value'),
            combo: document.getElementById('combo-value'),
            songTitle: document.getElementById('song-title'),
            notesContainer: document.getElementById('notes-container'),
            lanes: {
                left: document.getElementById('lane-left'),
                right: document.getElementById('lane-right')
            },
            finalScore: document.getElementById('final-score'),
            restartBtn: document.getElementById('restart-btn')
        };

        this.init();
    }

    init() {
        this.elements.connectBtn.addEventListener('click', () => this.connect());
        this.elements.debugBtn.addEventListener('click', () => this.startDebugMode());
        this.elements.restartBtn.addEventListener('click', () => this.resetGame());
        
        window.addEventListener('resize', () => this.calculateLayout());
        this.calculateLayout();
        
        // Key listeners for debug/testing
        window.addEventListener('keydown', (e) => {
            if (!this.isPlaying) return;
            if (e.key === 'ArrowLeft') this.handleInput('left');
            if (e.key === 'ArrowRight') this.handleInput('right');
        });
    }

    calculateLayout() {
        // Recalculate hit zone position
        // In CSS hit-zone is bottom: 15%.
        const containerHeight = this.elements.screens.game.clientHeight;
        this.hitZoneY = containerHeight * 0.85; // 100% - 15%
    }

    connect() {
        const url = this.elements.wsUrl.value;
        this.elements.status.textContent = `Connecting to ${url}...`;
        this.elements.status.style.color = '#fbbf24';

        try {
            this.socket = new WebSocket(url);

            this.socket.onopen = () => {
                this.elements.status.textContent = 'Connected! Waiting for game to start...';
                this.elements.status.style.color = '#34d399';
            };

            this.socket.onmessage = (event) => this.handleMessage(JSON.parse(event.data));

            this.socket.onclose = () => {
                this.elements.status.textContent = 'Disconnected';
                this.elements.status.style.color = '#ef4444';
                if (this.isPlaying) this.endGame();
            };

            this.socket.onerror = (error) => {
                console.error('WebSocket Error:', error);
                this.elements.status.textContent = 'Connection Error';
                this.elements.status.style.color = '#ef4444';
            };

        } catch (e) {
            this.elements.status.textContent = 'Invalid URL';
        }
    }

    handleMessage(msg) {
        console.log('Received:', msg);
        switch (msg.type) {
            case 'gameStart':
                this.startGame(msg);
                break;
            case 'sync':
                this.gameState.serverPlaybackTime = msg.playbackTime;
                this.gameState.lastSyncTime = performance.now();
                break;
            case 'tap':
                this.triggerFeedback(msg.side, msg.result || 'hit'); // 'hit' is internal falback
                break;
            case 'gameEnd':
                this.endGame(msg.finalScore);
                break;
        }
    }

    startDebugMode() {
        // Create a fake beat map
        const beatMap = [];
        for (let i = 0; i < 50; i++) {
            beatMap.push({
                time: 2.0 + (i * 0.8), // Start at 2s, every 0.8s
                side: i % 2 === 0 ? 'left' : 'right'
            });
        }
        
        const debugStartMsg = {
            type: 'gameStart',
            songTitle: 'Debug Beat - 120 BPM',
            bpm: 120,
            beatMap: beatMap
        };
        
        this.startGame(debugStartMsg);
        
        // Fake sync pulse
        this.debugInterval = setInterval(() => {
            if (!this.isPlaying) {
                clearInterval(this.debugInterval);
                return;
            }
            const timeSinceStart = (performance.now() - this.gameState.localStartTime) / 1000;
             this.handleMessage({ type: 'sync', playbackTime: timeSinceStart });
        }, 100);
    }

    startGame(data) {
        this.gameState.songTitle = data.songTitle;
        this.gameState.bpm = data.bpm;
        this.gameState.beatMap = data.beatMap;
        this.gameState.score = 0;
        this.gameState.combo = 0;
        this.gameState.localStartTime = performance.now();
        this.gameState.serverPlaybackTime = 0;
        this.gameState.lastSyncTime = performance.now();
        
        this.nextNoteIndex = 0;
        this.isPlaying = true;
        this.visibleNotes = [];
        this.elements.notesContainer.innerHTML = '';
        
        // Update UI
        this.elements.songTitle.textContent = this.gameState.songTitle;
        this.updateScore(0);
        this.updateCombo(0);
        
        this.switchScreen('game');
        
        requestAnimationFrame(() => this.loop());
    }

    loop() {
        if (!this.isPlaying) return;

        const now = performance.now();
        
        // Estimate current playback time:
        // Last Sync Time + (Time since Last Sync)
        const timeSinceSync = (now - this.gameState.lastSyncTime) / 1000;
        const currentPlaybackTime = this.gameState.serverPlaybackTime + timeSinceSync;

        // 1. Spawn new notes
        while (this.nextNoteIndex < this.gameState.beatMap.length) {
            const noteData = this.gameState.beatMap[this.nextNoteIndex];
            
            // If note is within lookahead window
            if (noteData.time - currentPlaybackTime <= this.lookaheadTime) {
                this.spawnNote(noteData);
                this.nextNoteIndex++;
            } else {
                break; // Notes are ordered by time, so we can stop
            }
        }

        // 2. Update visible notes
        const missedNotes = [];
        
        this.visibleNotes.forEach((noteObj, index) => {
            const timeDiff = noteObj.data.time - currentPlaybackTime;
            
            // Calculate Y position
            // When timeDiff = 0, Y = hitZoneY
            // When timeDiff > 0 (future), Y < hitZoneY (higher up)
            // Speed = pixels/sec
            
            const distance = timeDiff * this.noteSpeed;
            const yPos = this.hitZoneY - distance;
            
            // Update CSS
            noteObj.el.style.transform = `translate(-50%, ${yPos}px)`;
            
            // Check for miss (passed hit zone by too much)
            // Allow 200ms grace period?
            if (yPos > this.hitZoneY + 100) {
                missedNotes.push(index);
                this.triggerFeedback(noteObj.data.side, 'miss');
                this.resetCombo();
            }
        });
        
        // Remove missed notes (reverse order to not mess up indices)
        for (let i = missedNotes.length - 1; i >= 0; i--) {
            const idx = missedNotes[i];
            const note = this.visibleNotes[idx];
            if (note && note.el.parentNode) {
                note.el.remove();
            }
            this.visibleNotes.splice(idx, 1);
        }

        requestAnimationFrame(() => this.loop());
    }

    spawnNote(noteData) {
        const el = document.createElement('div');
        el.className = `note ${noteData.side}`;
        
        const inner = document.createElement('div');
        inner.className = 'note-inner';
        el.appendChild(inner);
        
        // Initial position (off screen top potentially)
        // lane: 25% or 75% of container width?
        // Actually we are putting them IN lane containers or absolute?
        // Let's put them in the notes-container which matches game-container dimensions
        // Left lane center: 25%, Right lane center: 75%
        
        const xPos = noteData.side === 'left' ? '25%' : '75%';
        el.style.left = xPos;
        
        this.elements.notesContainer.appendChild(el);
        
        this.visibleNotes.push({
            data: noteData,
            el: el,
            spawnTime: performance.now()
        });
    }

    handleInput(side) {
        // Show visual feedback immediately
        this.triggerBongoAnim(side);
        
        // In a real game with server, the server tells us if it was a hit
        // In debug mode, we simulate hit detection locally
        if (this.elements.wsUrl.value.includes('debug') || !this.socket) {
           this.checkHitLocally(side);
        }
    }

    checkHitLocally(side) {
         const now = performance.now();
         const timeSinceSync = (now - this.gameState.lastSyncTime) / 1000;
         const currentPlaybackTime = this.gameState.serverPlaybackTime + timeSinceSync;
         
         // Find closest note
         let hitIndex = -1;
         let minDiff = Infinity;
         
         for(let i=0; i < this.visibleNotes.length; i++) {
             const note = this.visibleNotes[i];
             if (note.data.side !== side) continue;
             
             const diff = Math.abs(currentPlaybackTime - note.data.time);
             if (diff < 0.2 && diff < minDiff) { // 200ms window
                 minDiff = diff;
                 hitIndex = i;
             }
         }
         
         if (hitIndex !== -1) {
             // Hit!
             const note = this.visibleNotes[hitIndex];
             note.el.remove();
             this.visibleNotes.splice(hitIndex, 1);
             
             let rating = 'good';
             let score = 50;
             if (minDiff < 0.05) { rating = 'perfect'; score = 100; }
             
             this.triggerFeedback(side, rating);
             this.addScore(score);
         }
    }

    triggerBongoAnim(side) {
        const lane = this.elements.lanes[side];
        lane.classList.remove('active');
        // Trigger reflow
        void lane.offsetWidth;
        lane.classList.add('active');
        setTimeout(() => lane.classList.remove('active'), 100);
    }

    triggerFeedback(side, rating) {
        // rating: 'perfect', 'good', 'miss'
        const container = side === 'left' ? 
            document.getElementById('feedback-left') : 
            document.getElementById('feedback-right');
            
        const el = document.createElement('div');
        el.className = `feedback-text ${rating}`;
        el.textContent = rating.toUpperCase();
        
        container.appendChild(el);
        
        // Clean up after animation
        setTimeout(() => el.remove(), 600);
        
        if (rating !== 'miss') {
            this.triggerBongoAnim(side);
        }
    }

    addScore(points) {
        this.gameState.combo++;
        this.gameState.score += (points * this.gameState.combo);
        this.updateScore(this.gameState.score);
        this.updateCombo(this.gameState.combo);
    }
    
    resetCombo() {
        this.gameState.combo = 0;
        this.updateCombo(0);
    }

    updateScore(val) {
        this.elements.score.textContent = val.toLocaleString();
    }
    
    updateCombo(val) {
        this.elements.combo.textContent = val;
    }

    endGame(finalScore) {
        this.isPlaying = false;
        if (finalScore !== undefined) {
             this.gameState.score = finalScore;
        }
        this.elements.finalScore.textContent = this.gameState.score.toLocaleString();
        this.switchScreen('results');
    }
    
    resetGame() {
        this.visibleNotes = [];
        this.elements.notesContainer.innerHTML = '';
        this.switchScreen('connection');
    }

    switchScreen(screenName) {
        Object.values(this.elements.screens).forEach(el => el.classList.add('hidden'));
        this.elements.screens[screenName].classList.remove('hidden');
    }
}

// Start app
window.onload = () => {
    const game = new BongoGame();
};

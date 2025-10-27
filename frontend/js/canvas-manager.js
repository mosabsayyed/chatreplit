/**
 * Canvas Manager - Handles 3-mode layout switching and artifact display
 * Modes: collapsed (25%), expanded (70%), fullscreen (100%)
 */

class CanvasManager {
    constructor() {
        this.currentMode = 'hidden'; // hidden, collapsed, expanded, fullscreen
        this.currentArtifact = null;
        this.artifacts = [];
        this.init();
    }
    
    init() {
        // Add canvas toggle button to header
        this.addCanvasToggle();
        
        // Create canvas workspace structure
        this.createCanvasWorkspace();
        
        // Load recent artifacts
        this.loadRecentArtifacts();
    }
    
    addCanvasToggle() {
        const headerRight = document.querySelector('.header-right');
        const toggleBtn = document.createElement('button');
        toggleBtn.id = 'canvasToggle';
        toggleBtn.className = 'canvas-toggle-btn';
        toggleBtn.textContent = '📊 Canvas';
        toggleBtn.onclick = () => this.toggleCanvas();
        
        // Insert before debug toggle
        const debugToggle = document.getElementById('debugToggle');
        headerRight.insertBefore(toggleBtn, debugToggle);
    }
    
    createCanvasWorkspace() {
        const mainContent = document.querySelector('.main-content');
        
        // Create canvas workspace HTML
        const canvasWorkspace = document.createElement('div');
        canvasWorkspace.id = 'canvasWorkspace';
        canvasWorkspace.className = 'canvas-workspace';
        canvasWorkspace.innerHTML = `
            <div class="canvas-header">
                <div class="canvas-title">Canvas Workspace</div>
                <div class="canvas-controls">
                    <button class="canvas-btn" onclick="canvasManager.cycleMode()">
                        <span id="canvasModeLabel">Expand</span>
                    </button>
                    <button class="canvas-btn" onclick="canvasManager.closeCanvas()">✕ Close</button>
                </div>
            </div>
            
            <div class="canvas-sidebar" id="canvasSidebar">
                <h3>Recent Artifacts</h3>
                <div class="artifact-list" id="artifactList">
                    <div class="canvas-empty-text">No artifacts yet</div>
                </div>
            </div>
            
            <div class="canvas-content" id="canvasContent" style="display: none;">
                <div class="canvas-empty">
                    <div class="canvas-empty-icon">📊</div>
                    <div class="canvas-empty-text">Select an artifact to view</div>
                    <div class="canvas-empty-subtext">or create one from the chat</div>
                </div>
            </div>
        `;
        
        mainContent.appendChild(canvasWorkspace);
    }
    
    toggleCanvas() {
        if (this.currentMode === 'hidden') {
            this.setMode('collapsed');
        } else {
            this.setMode('hidden');
        }
    }
    
    cycleMode() {
        const modes = ['collapsed', 'expanded', 'fullscreen'];
        const currentIndex = modes.indexOf(this.currentMode);
        const nextIndex = (currentIndex + 1) % modes.length;
        this.setMode(modes[nextIndex]);
    }
    
    closeCanvas() {
        this.setMode('hidden');
    }
    
    setMode(mode) {
        const workspace = document.getElementById('canvasWorkspace');
        const chatSection = document.querySelector('.chat-section');
        const sidebar = document.getElementById('canvasSidebar');
        const content = document.getElementById('canvasContent');
        const modeLabel = document.getElementById('canvasModeLabel');
        const toggleBtn = document.getElementById('canvasToggle');
        
        // Remove all mode classes
        workspace.classList.remove('mode-collapsed', 'mode-expanded', 'mode-fullscreen');
        chatSection.classList.remove('canvas-active', 'canvas-expanded', 'canvas-fullscreen');
        
        this.currentMode = mode;
        
        switch(mode) {
            case 'hidden':
                workspace.style.width = '0';
                toggleBtn.classList.remove('active');
                toggleBtn.textContent = '📊 Canvas';
                break;
                
            case 'collapsed':
                workspace.style.width = ''; // Clear inline width to let CSS class take over
                workspace.classList.add('mode-collapsed');
                chatSection.classList.add('canvas-active');
                sidebar.style.display = 'flex';
                content.style.display = 'none';
                toggleBtn.classList.add('active');
                toggleBtn.textContent = '📊 Canvas (On)';
                modeLabel.textContent = 'Expand';
                break;
                
            case 'expanded':
                workspace.style.width = ''; // Clear inline width to let CSS class take over
                workspace.classList.add('mode-expanded');
                chatSection.classList.add('canvas-expanded');
                sidebar.style.display = 'none';
                content.style.display = 'block';
                modeLabel.textContent = 'Fullscreen';
                break;
                
            case 'fullscreen':
                workspace.style.width = ''; // Clear inline width to let CSS class take over
                workspace.classList.add('mode-fullscreen');
                chatSection.classList.add('canvas-fullscreen');
                sidebar.style.display = 'none';
                content.style.display = 'block';
                modeLabel.textContent = 'Exit Fullscreen';
                break;
        }
    }
    
    async loadRecentArtifacts() {
        try {
            // TODO: Replace with actual API call
            // const response = await fetch('/api/v1/canvas/artifacts?limit=10');
            // const data = await response.json();
            // this.artifacts = data.artifacts;
            
            // For now, show empty state
            this.renderArtifactList();
        } catch (error) {
            console.error('Failed to load artifacts:', error);
        }
    }
    
    renderArtifactList() {
        const listContainer = document.getElementById('artifactList');
        
        if (this.artifacts.length === 0) {
            listContainer.innerHTML = '<div class="canvas-empty-text">No artifacts yet</div>';
            return;
        }
        
        listContainer.innerHTML = this.artifacts.map(artifact => `
            <div class="artifact-card" onclick="canvasManager.loadArtifact('${artifact.id}')">
                <div class="artifact-card-title">${artifact.title}</div>
                <div class="artifact-card-meta">${artifact.created_at}</div>
                <span class="artifact-type-badge">${artifact.artifact_type}</span>
            </div>
        `).join('');
    }
    
    async loadArtifact(artifactId) {
        const contentContainer = document.getElementById('canvasContent');
        
        // Show loading state
        contentContainer.innerHTML = `
            <div class="canvas-loading">
                <div class="canvas-loading-spinner"></div>
            </div>
        `;
        
        try {
            // TODO: Replace with actual API call
            // const response = await fetch(`/api/v1/canvas/artifacts/${artifactId}`);
            // const artifact = await response.json();
            
            // For now, show placeholder
            contentContainer.innerHTML = `
                <div class="artifact-container">
                    <div class="artifact-header">
                        <div class="artifact-title-main">Sample Artifact</div>
                        <div class="artifact-meta-row">
                            <div class="artifact-meta-item">
                                <span>📅</span>
                                <span>Created: Oct 27, 2025</span>
                            </div>
                            <div class="artifact-meta-item">
                                <span>👤</span>
                                <span>Version: 1</span>
                            </div>
                        </div>
                        <div class="artifact-actions">
                            <button class="export-btn">📥 Export PDF</button>
                            <button class="export-btn secondary">📄 Export DOCX</button>
                        </div>
                    </div>
                    <div class="artifact-body">
                        <p>Artifact content will be rendered here based on type.</p>
                    </div>
                </div>
            `;
            
            // Switch to expanded mode if in collapsed
            if (this.currentMode === 'collapsed') {
                this.setMode('expanded');
            }
            
        } catch (error) {
            console.error('Failed to load artifact:', error);
            contentContainer.innerHTML = `
                <div class="canvas-empty">
                    <div class="canvas-empty-icon">⚠️</div>
                    <div class="canvas-empty-text">Failed to load artifact</div>
                </div>
            `;
        }
    }
    
    createArtifact(type, title, content) {
        // This will be called when agent creates an artifact from chat
        const artifact = {
            id: Date.now().toString(),
            artifact_type: type,
            title: title,
            content: content,
            created_at: new Date().toISOString()
        };
        
        this.artifacts.unshift(artifact);
        this.renderArtifactList();
        
        // Auto-open canvas in collapsed mode
        if (this.currentMode === 'hidden') {
            this.setMode('collapsed');
        }
        
        return artifact;
    }
}

// Initialize canvas manager when DOM is loaded
let canvasManager;
document.addEventListener('DOMContentLoaded', () => {
    canvasManager = new CanvasManager();
});

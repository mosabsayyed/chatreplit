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
            // Find artifact in local cache
            const artifact = this.artifacts.find(a => a.id === artifactId);
            
            if (!artifact) {
                throw new Error('Artifact not found');
            }
            
            // Render based on artifact type
            this.renderArtifactByType(artifact);
            
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
    
    renderArtifactByType(artifact) {
        switch(artifact.artifact_type.toUpperCase()) {
            case 'CHART':
                if (typeof chartRenderer !== 'undefined') {
                    chartRenderer.render(artifact);
                } else {
                    console.error('ChartRenderer not loaded');
                }
                break;
            
            case 'REPORT':
                // TODO: Implement ReportRenderer
                this.renderPlaceholder(artifact, 'Report rendering coming soon');
                break;
            
            case 'TABLE':
                // TODO: Implement TableRenderer
                this.renderPlaceholder(artifact, 'Table rendering coming soon');
                break;
            
            case 'DOCUMENT':
                // TODO: Implement DocumentRenderer
                this.renderPlaceholder(artifact, 'Document rendering coming soon');
                break;
            
            default:
                this.renderPlaceholder(artifact, 'Unknown artifact type');
        }
    }
    
    renderPlaceholder(artifact, message) {
        const contentContainer = document.getElementById('canvasContent');
        contentContainer.innerHTML = `
            <div class="artifact-container">
                <div class="artifact-header">
                    <div class="artifact-title-main">${artifact.title}</div>
                    <div class="artifact-meta-row">
                        <div class="artifact-meta-item">
                            <span>📅</span>
                            <span>Created: ${new Date(artifact.created_at).toLocaleDateString()}</span>
                        </div>
                        <div class="artifact-meta-item">
                            <span>📦</span>
                            <span>Type: ${artifact.artifact_type}</span>
                        </div>
                    </div>
                </div>
                <div class="artifact-body">
                    <p>${message}</p>
                </div>
            </div>
        `;
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
        
        // Auto-open canvas and load the artifact
        if (this.currentMode === 'hidden') {
            this.setMode('collapsed');
        }
        
        // Auto-load the newly created artifact
        this.loadArtifact(artifact.id);
        
        return artifact;
    }
    
    // Helper method for testing - create sample chart
    createSampleChart() {
        const sampleChart = {
            type: 'radar',
            chart_title: 'Capability Maturity Assessment',
            subtitle: 'Current vs Target State',
            categories: ['Digital Twin', 'Process Mining', 'AI Orchestration', 'Analytics', 'Data Quality'],
            max_value: 5,
            series: [
                {
                    name: 'Current State',
                    data: [2, 3, 1, 4, 3],
                    pointPlacement: 'on',
                    color: '#ff6b6b'
                },
                {
                    name: 'Target State',
                    data: [5, 5, 4, 5, 5],
                    pointPlacement: 'on',
                    color: '#667eea'
                }
            ],
            description: 'This spider chart shows the current maturity level versus target state across five key transformation capabilities.'
        };
        
        return this.createArtifact('CHART', 'Capability Maturity Assessment', sampleChart);
    }
}

// Initialize canvas manager when DOM is loaded
let canvasManager;
document.addEventListener('DOMContentLoaded', () => {
    canvasManager = new CanvasManager();
});

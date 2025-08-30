class MemeGenerator {
    constructor() {
        this.urlParams = new URLSearchParams(window.location.search)
        this.initializeElements()
        this.bindEvents()
        this.isGenerating = false
    }

    initializeElements() {
        // Form elements
        this.form = document.getElementById('imageForm')
        this.promptInput = document.getElementById('promptInput')
        this.generateBtn = document.getElementById('generateBtn')
        this.resetBtn = document.getElementById('resetBtn')
        this.btnText = this.generateBtn.querySelector('.btn-text')
        this.spinner = this.generateBtn.querySelector('.spinner')

        // Alert elements
        this.errorAlert = document.getElementById('errorAlert')
        this.errorMessage = document.getElementById('errorMessage')

        // Card elements
        this.loadingCard = document.getElementById('loadingCard')
        this.imageCard = document.getElementById('imageCard')
        this.generatedImage = document.getElementById('generatedImage')
        this.imagePrompt = document.getElementById('imagePrompt')
        this.downloadBtn = document.getElementById('downloadBtn')
    }

    bindEvents() {
        this.form.addEventListener('submit', (e) => this.handleSubmit(e))
        this.resetBtn.addEventListener('click', () => this.handleReset())
        this.downloadBtn.addEventListener('click', () => this.handleDownload())
        this.promptInput.addEventListener('input', () => this.clearError())
        this.promptInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault()
                this.form.requestSubmit()
            }
        })
        this.promptInput.value = this.urlParams.get('prompt')
    }

    async handleSubmit(e) {
        e.preventDefault()

        if (this.isGenerating) return

        const prompt = this.promptInput.value.trim()
        if (!prompt) {
            this.showError('Please enter a description for your image')
            this.promptInput.focus()
            return
        }

        if (prompt.length < 3) {
            this.showError('Please provide a more detailed description')
            this.promptInput.focus()
            return
        }

        this.setLoadingState(true)
        this.clearError()
        this.hideImageCard()

        try {
            const response = await this.generateImage(prompt)
            const data = await response.json();

            const phrases = JSON.parse(data.generated_text);

            phrases.simple = data.input_text;

            this.displayImage(phrases)

        } catch (error) {
            console.error('Image generation error:', error)
            this.showError(this.getErrorMessage(error))
        } finally {
            this.setLoadingState(false)
        }
    }

    async generateImage(prompt) {

        const apiUrl = window.lambda_function_endpoint + '?prompt=' + prompt
        return fetch(apiUrl, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            }
        })

    }

    setLoadingState(isLoading) {
        this.isGenerating = isLoading

        if (isLoading) {
            this.generateBtn.disabled = true
            this.promptInput.disabled = true
            this.btnText.textContent = 'Generating...'
            this.spinner.classList.remove('hidden')
            this.loadingCard.classList.remove('hidden')

            // Add subtle animation to the input
            this.promptInput.style.animation = 'pulse 2s infinite'
        } else {
            this.generateBtn.disabled = false
            this.promptInput.disabled = false
            this.btnText.textContent = 'Generate Image'
            this.spinner.classList.add('hidden')
            this.loadingCard.classList.add('hidden')

            // Remove animation
            this.promptInput.style.animation = ''
        }
    }

    displayImage(phrases) {
        document.getElementById('phrase-simple').innerText = phrases.simple;
        document.getElementById('phrase-complex').innerText = phrases.complex;
        document.getElementById('phrase-sophisticated').innerText = phrases.sophisticated;

        // Smooth reveal animation
        this.imageCard.classList.remove('hidden')
        this.resetBtn.classList.remove('hidden')

        // Scroll to image smoothly
        setTimeout(() => {
            this.imageCard.scrollIntoView({
                behavior: 'smooth',
                block: 'center'
            })
        }, 100)
    }

    hideImageCard() {
        this.imageCard.classList.add('hidden')
    }

    handleReset() {
        this.promptInput.value = ''
        this.hideImageCard()
        this.clearError()
        this.resetBtn.classList.add('hidden')
        this.promptInput.focus()

        // Smooth scroll back to top
        this.form.scrollIntoView({
            behavior: 'smooth',
            block: 'center'
        })
    }

    async handleDownload() {
        const element = document.getElementById('imageContainer')
        if (!element) return

        html2canvas(element).then(function (canvas) {
            const imageDataUrl = canvas.toDataURL('image/png');

            // Create a temporary anchor element to trigger the download
            const link = document.createElement('a');
            link.href = imageDataUrl;
            link.download = 'pooh_meme.png'; // Set the filename for the downloaded image

            // Append the link to the document body and simulate a click to trigger the download
            document.body.appendChild(link);
            link.click();

            // Clean up by removing the temporary link from the document
            document.body.removeChild(link);
        });
    }

    showError(message) {
        this.errorMessage.textContent = message
        this.errorAlert.classList.remove('hidden')

        // Auto-hide error after 5 seconds
        setTimeout(() => {
            this.clearError()
        }, 5000)
    }

    clearError() {
        this.errorAlert.classList.add('hidden')
        this.errorMessage.textContent = ''
    }

    getErrorMessage(error) {
        const message = error.message.toLowerCase()

        if (message.includes('network') || message.includes('fetch')) {
            return 'Network error. Please check your connection and try again.'
        } else if (message.includes('timeout')) {
            return 'Request timed out. Please try again.'
        } else if (message.includes('401') || message.includes('unauthorized')) {
            return 'Authentication failed. Please check your API key.'
        } else if (message.includes('429') || message.includes('rate limit')) {
            return 'Too many requests. Please wait a moment and try again.'
        } else if (message.includes('500') || message.includes('server')) {
            return 'Server error. Please try again later.'
        } else {
            return error.message || 'An unexpected error occurred. Please try again.'
        }
    }
}

// Initialize the application
document.addEventListener('DOMContentLoaded', () => {
    new MemeGenerator()
})

// Add some interactive sparkle effects
document.addEventListener('mousemove', (e) => {
    if (Math.random() > 0.98) {
        createSparkle(e.clientX, e.clientY)
    }
})

function createSparkle(x, y) {
    const sparkle = document.createElement('div')
    sparkle.style.cssText = `
                position: fixed;
                left: ` + x + `px;
                top: ` + y + `px;
                width: 4px;
                height: 4px;
                background: linear-gradient(45deg, #4285f4, #9c27b0);
                border-radius: 50%;
                pointer-events: none;
                z-index: 1000;
                animation: sparkleAnimation 1s ease-out forwards;
            `

    document.body.appendChild(sparkle)

    setTimeout(() => {
        sparkle.remove()
    }, 1000)
}
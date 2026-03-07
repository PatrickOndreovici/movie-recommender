import { Controller } from "@hotwired/stimulus"
// import { S3Client, UploadPartCommand, CompleteMultipartUploadCommand } from "@aws-sdk/client-s3"

export default class extends Controller {

    static targets = ["file", "fileName", "progressBar", "progressContainer", "uploadingState", "uploadingText", "submitButton", "title", "description", "genre", "year"]
  
    CHUNK_SIZE = 5 * 1024 * 1024;


    connect() {
      console.log("Upload controller connected")
    }
  
    async start() {
        const file = this.fileTarget.files[0]
        const fileSize = file.size
        const csrf = document.querySelector("meta[name='csrf-token']").getAttribute("content")

        this.showUploading(true)

        try {
            const response = await fetch('/movies/initiate-upload', {
                method: 'POST',
                body: JSON.stringify({
                    movie_title: this.titleTarget.value,
                    movie_description: this.descriptionTarget.value,
                    movie_genre: this.genreTarget.value,
                    movie_release_year: this.yearTarget.value,
                    file_size: fileSize
                }),
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': csrf
                }
            })

            const data = await response.json()
            const numberOfParts = data.presigned_urls.length
            const parts = []

            for (let i = 0; i < numberOfParts; i++) {
                const part = file.slice(i * this.CHUNK_SIZE, Math.min((i + 1) * this.CHUNK_SIZE, fileSize))
                const url = data.presigned_urls[i].url
                const partNumber = data.presigned_urls[i].part_number
                const result = await this.uploadFileToS3(part, partNumber, url)
                parts.push(result)
                this.setProgress(((i + 1) / numberOfParts) * 100)
            }

            await this.completeUpload(this.titleTarget.value, data.upload_id, parts, csrf)
            this.uploadingTextTarget.textContent = "Upload complete!"
        } catch (err) {
            console.error(err)
            this.uploadingTextTarget.textContent = "Upload failed. Please try again."
        } finally {
            this.showUploading(false)
        }
    }

    showUploading(show) {
        this.submitButtonTarget.disabled = show
        this.uploadingStateTarget.classList.toggle("hidden", !show)
        this.uploadingStateTarget.classList.toggle("flex", show)
        this.progressContainerTarget.classList.toggle("hidden", !show)
        if (!show) return
        this.uploadingTextTarget.textContent = "Uploading video…"
        this.setProgress(0)
    }

    setProgress(percent) {
        this.progressBarTarget.style.width = `${Math.round(percent)}%`
    }

    async uploadFileToS3(part, partNumber, url) {
        const response = await fetch(url, {
            method: 'PUT',
            body: part,
            headers: {
                'Content-Type': 'application/octet-stream'
            }
        })
        const etag = response.headers.get("ETag")
        return { partNumber, etag }
    }


    async completeUpload(title, uploadId, parts, crsf) {
        const response = await fetch('/movies/complete-upload', {
            method: 'POST',
            body: JSON.stringify({
                movie_title: title,
                upload_id: uploadId,
                parts: parts
            }),
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': crsf
            }
        })

        const result = await response.json()
        if (!response.ok) throw new Error(result.message || "Complete upload failed")
    }
}
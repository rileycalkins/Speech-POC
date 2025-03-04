# File-Based Speech Transcription for macOS (R&D Proof of Concept) [In Development]


This project was developed as a proof of concept to explore the capabilities of speech transcription on macOS. 

Utilizing Apple's [**Speech**](https://developer.apple.com/documentation/speech/) framework, it transcribes audio files into text. Additionally, the integration of the [**Natural Language**](https://developer.apple.com/documentation/naturallanguage/) framework allows for tagging and semantic analysis of the transcriptions, enabling more nuanced and meaningful data extraction. 

The goal of this R&D effort was to investigate the potential for building intuitive applications that leverage built-in macOS technologies. The findings from this project can serve as a foundation for more complex applications, such as automated transcription services, or accessibility tools. 

Further development could explore enhancements like improved contextual understanding in tagging.

# Features
* **Audio File Transcription**:
    * Upload and transcribe audio files
* **Natural Language Tagging**:
    * Automatically generate tags for saved transcriptions
* **Transcription Management**:
    * Save, edit, and delete transcriptions from a split view interface

# Prerequisites & Installation
* macOS Sequoia 15.0 or later
* Xcode 16+
* Clone, open and build the project in Xcode

# Usage

### Transcribing Audio Files
1. Upload an audio file using the file picker.
2. The app will automatically transcribe the audio and display the text.
3. After transcription is complete, click the **Save** button to save the transcription to the list of recordings.
4. After saving, the app will switch to the split view, where you can edit your transcription and tags.

### Managing Transcriptions
1. On the left side of the split view, you'll see a list of your saved transcriptions.
2. Click on any transcription to view and edit its details on the right side of the split view.
3. You can edit the transcription title, content, and tags. Click the **Save** button to update the transcription.
4. To delete a transcription, click on the trash icon in the toolbar.

> [!WARNING]
> 
> When there is no audio input device connected, the app may not function as expected (you can obviously use your built-in microphone on your macOS machine but if you're using a Mac mini, for example, I highly recommend connecting using your AirPods or some other input source).


NoteWave

NoteWave is a modern iOS voice note application that enables users to record, merge, transcribe, and interact with audio notes using AI. Built using Swift + MVVM architecture, it focuses on reliability, clean design, and intelligent audio processing.

 Features
 
Voice Recording
Real-time waveform visualization
Crash-safe recording using CAF (Linear PCM) format
Prevents data loss even on app termination

 Audio Processing
 
Merge multiple recordings into a single file
Convert CAF → AAC (.m4a) for optimized storage

 AI Transcription
 
Speech-to-text using Apple Speech Framework
High accuracy transcription pipeline

 AI Assistant
 
Chat with voice notes
Summarize and extract insights
Powered by Google Gemini and OpenAI

 Architecture
 
MVVM Architecture
SwiftUI for UI layer
ViewModels handle business logic using @Observable
Service layer for:
Audio recording
Transcription
AI integration

 Tech Stack
 
Swift
SwiftUI
SwiftData
AVFoundation
Speech Framework
Google Gemini API
OpenAI API
async/await (Concurrency)

 Audio System
 
Recording format: CAF (Linear PCM) for crash safety
Export format: AAC (.m4a) using AVAssetExportSession
Ensures performance + storage optimization

 Data Storage
 
SwiftData used for metadata storage:
File path
Duration
Transcript
Audio files stored in iOS Documents Directory (Sandbox)

 Author

Samuel Sajeev


 Note

To enable AI features, add your own API keys:

Google Gemini API key
OpenAI API key

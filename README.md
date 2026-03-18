# **Highlight Reader Project**

| Name | Link |
| :---- | :---- |
| **Github** | [widgetpresentation\_highlighting-app](https://github.com/josep-prog/widgetpresentation_highlighting-app.git)  |
| **Documentation reference used** |  [Flutter Speech to Text App  by Marcus Ng](https://youtu.be/wDWoD1AaLu8)  [Flutter\_text\_highlight](https://github.com/TechIsFun/flutter_text_highlight.git)  [richtext widget \[Documentation of how richtext is used\]](https://pub.dev/packages/text_highlight)  |
| **reader\_page.dart** | [reader\_page.dart](https://github.com/josep-prog/widgetpresentation_highlighting-app/blob/main/lib/reader_page.dart)  |

## **1\. What the App Does**

Highlight Reader is a Flutter app I built to help people read along with audio. You upload a document (TXT, PDF, or DOCX) and an audio recording of that document being read aloud. The app highlights the sentence currently being spoken and automatically scrolls the text, similar to Kinyarwanda bible. 

The app does not transcribe the audio or compare it word by word. Instead, it calculates timing based on the total audio duration and the number of words. For instance, if a document has 100 words and the audio is 60 seconds long, the app estimates each word takes about 0.6 seconds. Some words may appear faster or slower depending on how they are actually spoken, so this is not perfectly precise. My main goal was to demonstrate dynamic sentence highlighting and scrolling in real time.

## **2\. Widgets Used and Their Contribution**

The main widgets I used in Highlight Reader are **SingleChildScrollView** and **RichText**, each serving a key role.

**SingleChildScrollView** allows the entire document to be scrollable, so as the audio plays and the current sentence is highlighted, the view can move smoothly to keep it visible. Without it, the text would remain static, and the reader would have to manually scroll to follow along, breaking the dynamic reading experience.

**RichText** enables combining text with embedded widgets, which is essential for highlighting sentences dynamically. Each word or sentence is wrapped in a container, and RichText lets the app change its style, for example, adding a yellow background to the current sentence while keeping the rest of the text readable. This combination of widgets makes the highlighting and scrolling mechanism both functional and visually clear for the reader.

## **3\. How It Works (Logic)**

The process is simple and works only if the audio matches the document exactly:

* **Document Upload:** The app extracts all words from the uploaded document.

* **Sentence Grouping:** Words are grouped into sentences based on punctuation (periods, exclamation marks, question marks).

* **Audio Upload:** You upload an audio file that exactly corresponds to the document.

* **Weighted Timing:** The total audio duration is divided across all words and sentences. Longer sentences or sentences ending with punctuation get slightly more time.

* **Highlighting & Scrolling:** As audio plays, the app estimates which sentence is currently spoken and highlights it in yellow. The scroll view keeps the sentence in view automatically.

* The audio must match the document exactly. Since there’s no transcription or comparison happening, mismatched audio will cause the highlighting to drift. Even with matching audio, some words may appear slightly out of sync if spoken faster or slower. Despite this, the app successfully demonstrates how dynamic sentence highlighting can work.

## **4\. Project Structure**

I kept the code simple and minimal:

* **main.dart** : launches the app and shows the main page

* **reader\_page.dart** : contains all logic, highlighting, scrolling, and UI

* **audio\_helper.dart** : handles web audio (stub)

* **audio\_helper\_native.dart** : handles audio for Android
from moviepy.editor import VideoFileClip
import os

# Directory where the videos are stored
video_dir = r"C:\Users\nadege\Data\CORTIFY\Cortify_Media\Create_Playlists\Vidéos"

# Directory where the thumbnails will be saved
thumbnail_dir = r"C:\Users\nadege\Data\CORTIFY\Cortify_Media\images\Video thumbnails"

# Loop through each file in the video directory
for filename in ["Metropolis (1927).mp4"]:  # os.listdir(video_dir):
    if filename.endswith(".mp4"):  # Ensure we're working with MP4 files
        video_path = os.path.join(video_dir, filename)
        video = VideoFileClip(video_path)

        # Resize the clip
        video = video.resize(height=400)

        # Generate and save thumbnail
        thumbnail_time = video.duration / 5  # You can adjust this as needed
        thumbnail_path = os.path.join(thumbnail_dir, f"{os.path.splitext(filename)[0]}.jpg")
        video.save_frame(thumbnail_path, t=thumbnail_time)

        # Close the clip to free up system resources
        video.close()

print("Thumbnail generation completed.")

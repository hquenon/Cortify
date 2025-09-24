import os
import glob
import json
from moviepy.video.io.VideoFileClip import VideoFileClip
from tinytag import TinyTag
import pandas as pd

"""
This script collects metadata from audio and video files stored in Create_Playlists,
organizes the metadata by stimulus type, and saves it to a JSON file.
"""


def get_video_duration(file_path):
    """
    Extract duration from a video file.
    Args:
        file_path: string, path to the video file
    Returns:
        duration: float, duration of the video file in seconds
    """
    clip = VideoFileClip(file_path)
    duration = clip.duration
    clip.close()
    return duration


def get_cover_image(tag, cover_path, filename):
    """
    Search for the cover image in the specified directory.
    Args:
        tag: TinyTag object, contains metadata about the file
        cover_path: string, path to the directory with cover images
        filename: string, name of the file
    Returns:
        cover_file: string, name of the cover image file
    """
    for cover_file in os.listdir(cover_path):
        if tag.album and os.path.splitext(cover_file)[0].lower() == tag.album.lower():
            return cover_file
        elif tag.artist and os.path.splitext(cover_file)[0].lower() == tag.artist.lower():
            return cover_file
        elif os.path.splitext(cover_file)[0].lower() == filename[:-4].lower():
            return cover_file
    return None


def collect_metadata(file, stim_type, cover_path, priority):
    """
    Collects and organizes metadata for a given file.
    Args:
        file: string, path to the media file
        stim_type: string, type of the stimulus
        cover_path: string, path to the directory with cover images
    Returns:
        metadata: dict, contains the metadata of the file
    """
    tag = TinyTag.get(file)
    ext = os.path.splitext(file)[-1]
    filename = file.split('\\')[-1]

    duration = get_video_duration(file) if ext == ".mp4" else tag.duration
    cover = cover_path + ("/Video thumbnails/" if ext == ".mp4" else "/Album covers/")
    album_cover = get_cover_image(tag, cover, filename)

    return {
        "filename": filename,
        "stim_type": stim_type,
        "format": ext,
        "duration": duration,
        "artist": tag.artist,
        "album": tag.album,
        "title": tag.title,
        "channels": tag.channels,
        "bitrate": tag.bitrate,
        "audio_offset": tag.audio_offset,
        "filesize": tag.filesize,
        "samplerate": tag.samplerate,
        "album_cover": album_cover,
        "priority": priority,
    }

def get_priority_files_from_excel(excel_file):
    df = pd.read_excel(excel_file)  # Charge le fichier Excel
    priority_files = df['filename'].tolist()  # Obtient la liste des fichiers prioritaires
    return priority_files

def process_files(filepath, cover_path, extensions, excel_file):
    """
    Iterates over all files in the specified directory and organizes them by metadata.
    Args:
        filepath: string, path to the directory with media files
        cover_path: string, path to the directory with cover images
        extensions: list, list of file extensions to look for
        excel_file : path to the excel_file with the priority_files
    Returns:
        metadata_dict: dict, contains all the metadata organized by stimulus type
    """

    print("Parsing directory:", filepath)

    priority_files = get_priority_files_from_excel(excel_file)
    print(priority_files)

    metadata_dict = {}
    for stim_type in os.listdir(filepath):
        stim_type_dir = os.path.join(filepath, stim_type)
        if os.path.isdir(stim_type_dir):
            print(stim_type)
            metadata_list = []
            for ext in extensions:
                for file in glob.glob(os.path.join(stim_type_dir, f'*{ext}')):
                    print("  -", file.split('\\')[-1])
                    priority = os.path.basename(file) in priority_files
                    metadata = collect_metadata(file, stim_type, cover_path, priority)
                    metadata_list.append(metadata)

            sorted_metadata = sorted(metadata_list, key=lambda x: (
                x["artist"] or "", x["album"] or "", x["filename"]
            ))

            metadata_dict[stim_type] = {metadata["filename"]: metadata for metadata in sorted_metadata}
    print('metadat_dict :', metadata_dict)
    return metadata_dict


def save_to_json(metadata, filepath, filename):
    """
    Saves the given metadata dictionary to a JSON file.
    Args:
        metadata (dict): dict, dictionary containing the metadata
        filepath (str, path) : folder to save the JSON file in
        filename (str):
    """
    json_path = os.path.join(filepath, filename)
    with open(json_path, 'w') as f:
        json.dump(metadata, f, indent=4)
    print("Saved playlist as", json_path)


def create_json_playlist(cortify_media_path):
    filepath = os.path.join(cortify_media_path, 'Create_Playlists', 'media')
    cover_path = os.path.join(cortify_media_path, 'images')
    extensions = ['.wav', '.mp3', '.mp4']
    excel_file = r"C:\Users\nadege\Desktop\camille\priorities.xlsx"

    metadata = process_files(filepath, cover_path, extensions, excel_file)
    save_to_json(metadata, os.path.join(cortify_media_path, 'Create_Playlists', 'metadata'), 'metadata.json')
    #print('metadata_dict :', metadata)



if __name__ == '__main__':
    create_json_playlist(r"C:\Users\nadege\Data\CORTIFY\Cortify_Media")

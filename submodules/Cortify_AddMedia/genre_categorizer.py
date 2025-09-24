import os
import shutil
from tinytag import TinyTag

"""
This script collects metadata from audio and video files stored in "Add_Triggers/stimuli_with_triggers",
sorts them by genre, and copies them to the appropriate directory under "Create_Playlists".
"""


def collect_genre_metadata(file):
    """
    Collects the genre metadata for a given file.
    Args:
        file: path to the media file
    Returns:
        (str): genre of the media file
    """
    tag = TinyTag.get(file)
    return tag.genre


def copy_files_by_genre(filepath, destination_folder_mapping: dict, overwrite: bool =False):
    """
    Copies files to the appropriate directory based on their genre.
    If a file with the same name exists in the destination directory,
    it will be overwritten if the 'overwrite' parameter is True.
    Args:
        filepath: path to the directory with media files
        destination_folder_mapping (dict): mapping from genre to the destination folder
        overwrite (bool): whether to overwrite existing files
    """
    for file in os.listdir(filepath):
        print(file)
        file_path = os.path.join(filepath, file)
        if os.path.isfile(file_path):
            genre = collect_genre_metadata(file_path)

            if genre in destination_folder_mapping:
                destination_folder = destination_folder_mapping[genre]

                # Check if the destination folder exists and create it if necessary
                os.makedirs(destination_folder, exist_ok=True)

                destination_file_path = os.path.join(destination_folder, file)

                if not os.path.exists(destination_file_path) or overwrite:
                    shutil.copy(file_path, destination_file_path)
                    print(f"Copied {file} to {destination_folder}")
                else:
                    print(f"Skipped {file} as it already exists in destination folder {destination_folder}")



def sort_stim_with_triggers_to_genre_subfolders(cortify_media_path, overwrite=False):
    """
    Checks for files in `Cortify_Media > Add_Triggers > stimuli_with_triggers`.

    Categorizes files based on their genre (collected from metadata) and copies files into their
    respective subfolders under `Cortify_Media > Create_Playlists > Audiobooks`, `Music`, `Podcasts`
    & `Vidéos`.

    The arg `overwrite` determines whether existing files in the destination folders should be overwritten.

    Args:
        cortify_media_path (Union[str, Path]): Path to the 'Cortify_Media' directory.
        overwrite (bool, optional): A flag to determine whether to overwrite existing files in the
            destination directory. Defaults to False.
    """

    input_path = os.path.join(cortify_media_path, 'Add_Triggers', 'stimuli_with_triggers')
    media_path = os.path.join(cortify_media_path, 'Create_Playlists', 'media')

    # Define mapping of genre to destination folder
    destination_folder_mapping = {
        'Audiobooks': os.path.join(media_path, 'Audiobooks'),
        'Musique': os.path.join(media_path, 'Musique'),
        'Podcast': os.path.join(media_path, 'Podcasts'),
        'Vidéos': os.path.join(media_path, 'Vidéos')
    }

    copy_files_by_genre(input_path, destination_folder_mapping, overwrite)


if __name__ == '__main__':
    sort_stim_with_triggers_to_genre_subfolders(cortify_media_path=r"C:\Users\nadege\Data\CORTIFY\Cortify_Media")

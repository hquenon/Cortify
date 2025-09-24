import os
import random
import subprocess
from glob import glob
from collections import namedtuple

import eyed3
import librosa
import matplotlib.pyplot as plt
import numpy as np
import soundfile as sf
import taglib
from moviepy.audio import AudioClip

from moviepy.video.VideoClip import ColorClip
from moviepy.video.compositing.concatenate import concatenate_videoclips
from moviepy.video.io.VideoFileClip import VideoFileClip


# Decide how much silence to append to the start of stim files
# (to account for delay when launching a new acquisition block on the hospital acquisition system - trigger 201)
SILENCE_DURATION = 3.0  # seconds

# Define a namedtuple for trigger-related parameters
TriggerParams = namedtuple("TriggerParams", ["trigger_amplitude", "trigger_duration", "min_trigger_spacing",
                                             "max_trigger_spacing", "initial_trigger_pos"])
PARAMS = TriggerParams(
    trigger_amplitude=1,
    trigger_duration=0.002,
    min_trigger_spacing=0.5,
    max_trigger_spacing=1.5,
    initial_trigger_pos=[SILENCE_DURATION, SILENCE_DURATION + .2, SILENCE_DURATION + .4]
)


def add_silence(audio: np.ndarray, sample_rate: int, silence_duration: float = SILENCE_DURATION):
    """
    Adds silence to the beginning of the audio.

    :param audio: (numpy.ndarray) The input audio as a NumPy array.
    :param sample_rate: (int) The sample rate of the audio in Hz.
    :param silence_duration: (float) The duration of the silence to be added at the start of the audio, in seconds.
        Defaults to 3 seconds to account for delay when launching a new acquisition block on the hospital acquisition
        system (trigger 201).

    :return: (numpy.ndarray) The audio with added silence.
    """

    silence = np.zeros(int(silence_duration * sample_rate))
    return np.concatenate((silence, audio))


def generate_new_trigger_signal(file_name: str, num_samples: int, sample_rate: int, trigger_pos_path: str,
                                trigger_params: TriggerParams):
    """
    Creates a trigger signal of a given duration and sample rate.
    Three triggers spaced by 200 ms mark the start of the audio (end of the 3 sec of added silence), then the rest of
    the trigger events are spaced randomly throughout the signal (see function parameters for trigger duration,
    min and max spacing, amplitude).
    The trigger positions are saved in seconds (in decimal format) to a text file in the 'triggers' folder.

    :param file_name: name of the stim file (without extension)
    :param num_samples: The duration of the trigger signal in time samples.
    :param sample_rate: (int) The sample rate of the trigger signal in Hz.
    :param trigger_pos_path: (str) The path to the output triggers folder.
    :param trigger_params: (TriggerParams) Parameters related to the trigger configuration, including:
        `trigger_duration`: (float) Duration of each trigger event in seconds.
        `min_trigger_spacing` (float) Minimum spacing between trigger events in seconds.
        `max_trigger_spacing` (float) Maximum spacing between trigger events in seconds.
        `trigger_amplitude`: (float) Amplitude of each trigger event, between 0 and 1.
        `initial_trigger_pos`: (list) Position of the first triggers (tag to mark the start of each file)

    :return: (numpy.ndarray) The trigger signal as a 1D NumPy array of zeros and ones,
      with ones representing the trigger events.
    """

    # Compute trigger duration in number of samples
    trigger_duration_samples = int(trigger_params.trigger_duration * sample_rate)

    # Initialize the trigger arrays with zeros
    trigger_signal = np.zeros(num_samples)
    trigger_positions = np.zeros((int(num_samples / trigger_duration_samples), 2))

    # Add the 3 initial triggers
    for i, trigger_position in enumerate(trigger_params.initial_trigger_pos):
        start_index = int(trigger_position * sample_rate)
        end_index = start_index + trigger_duration_samples

        trigger_positions[i, 0] = trigger_position
        trigger_signal[start_index:end_index] = trigger_params.trigger_amplitude
        trigger_positions[i, 1] = trigger_position + trigger_params.trigger_duration

    # Add the rest of the triggers, randomly spaced throughout the file
    while end_index < num_samples - 1 * sample_rate:  # run until 1 second from end

        trigger_position += random.uniform(trigger_params.min_trigger_spacing,
                                           trigger_params.max_trigger_spacing) + trigger_params.trigger_duration

        start_index = int(trigger_position * sample_rate)
        end_index = start_index + trigger_duration_samples

        trigger_positions[i, 0] = trigger_position
        trigger_signal[start_index:end_index] = trigger_params.trigger_amplitude
        trigger_positions[i, 1] = trigger_position + trigger_params.trigger_duration

        i += 1

    # End with a trigger
    trigger_signal[-trigger_duration_samples:] = trigger_params.trigger_amplitude

    trigger_positions[i, 0] = (num_samples - trigger_duration_samples) / sample_rate
    trigger_positions[i, 1] = num_samples / sample_rate

    # Remove trailing zeros from the trigger positions array
    trigger_positions = trigger_positions[~np.all(trigger_positions == 0, axis=1)]

    # Get output file path
    trigger_output_file = os.path.join(trigger_pos_path, file_name + '_trigger.txt')

    # Save the trigger positions
    np.savetxt(trigger_output_file, trigger_positions, delimiter=',', fmt='%0.6f')
    print(f"Trigger positions saved to file: {trigger_output_file}")

    return trigger_signal


def generate_trigger_signal_from_txt(file_name, audio_num_samples, audio_sampling_rate,
                                   trigger_pos_path, trigger_amplitude=1):

    # Get output file path
    trigger_pos_file = os.path.join(trigger_pos_path, file_name + '_trigger.txt')

    # load the trigger timings from the text file
    with open(trigger_pos_file, 'r') as f:
        trigger_positions = [line.strip().split(',') for line in f]

    # convert the trigger timings to a numpy array
    trigger_positions = np.array(trigger_positions, dtype=float) * audio_sampling_rate

    # Init trigger signal
    trigger_signal = np.zeros(audio_num_samples)

    # Add triggers
    for trigger_onset, trigger_offset in np.round(trigger_positions):
        trigger_signal[int(trigger_onset):int(trigger_offset + 1)] = trigger_amplitude

    return trigger_signal


def create_trigger_signal(use_existing_txt_file: bool,
                          audio: np.ndarray, sample_rate: int,
                          file_name: str, trigger_pos_path: str):
    """
    Generate or recreate a trigger signal for a given audio, and combine them.

    This function either generates a new trigger signal or uses existing trigger positions
    to recreate a trigger signal based on the `use_existing_txt_file` flag. The resulting
    signal is then combined with the provided audio.

    Parameters:
    :param use_existing_txt_file: (bool) If True, the function uses existing trigger positions saved in a .txt file.
    :param audio: (numpy.ndarray) The input audio signal.
    :param sample_rate: (int) The sample rate of the audio.
    :param file_name: (str) Name of the audio file (used to find the corresponding .txt file if necessary).
    :param trigger_pos_path: (str) Path to the directory containing trigger position .txt files.

    :return: (numpy.ndarray) The combined audio with the trigger signal on a separate channel.
    """

    # Add silence to the start of the audio
    audio = add_silence(audio, sample_rate)

    if use_existing_txt_file:
        # Create trigger signal from existing trigger positions
        trigger_signal = generate_trigger_signal_from_txt(file_name, audio.shape[0], sample_rate, trigger_pos_path)
    else:
        # Create new trigger signal and save positions to .txt
        trigger_signal = generate_new_trigger_signal(file_name, audio.shape[0], sample_rate, trigger_pos_path, PARAMS)

    # Combine audio and trigger signals
    audio_with_triggers = np.column_stack((audio, trigger_signal))

    return audio_with_triggers


def add_triggers_to_audio(file_name: str, extension: str, file_paths: namedtuple,
                          sample_rate, metadata: dict, use_existing_txt_file=True, plot=False):
    """
    Process an audio file, add triggers and save it with metadata.

    :param file_name: (str) Name of the audio file.
    :param extension: (str) Extension of the audio file (mp3 or wav)
    :param file_paths: (namedtuple FilePaths) Contains paths:
        `media_file_path`: Path to the source audio without triggers.
        `stimuli_file_path`: Path where the new stimulus file with triggers will be saved.
        `trigger_file_path`: Path to save the trigger positions.
    :param sample_rate: (int) Sample rate of the audio.
    :param metadata: (dict) Metadata information.
    :param use_existing_txt_file: (bool) If true and a .txt file exists in the output dir,
        use the saved positions to recreate the trigger signal
    :param plot: (bool) If True, plots the new audio data with triggers on ch 2.
    """

    # Load audio
    audio, sr = librosa.load(os.path.join(file_paths.source_media_path, file_name + extension), sr=sample_rate)

    # Add triggers
    audio_with_triggers = create_trigger_signal(use_existing_txt_file, audio, sample_rate,
                                                file_name, file_paths.trigger_pos_path)

    # Plot the stereo sound if requested
    if plot:
        plot_stereo_audio(audio_with_triggers.T, sample_rate, file_name)

    # Save the audio with triggers as a mp3 file
    output_abs_filepath = os.path.join(file_paths.stim_with_trigs_path, file_name + ".mp3")
    sf.write(output_abs_filepath, audio_with_triggers, sample_rate)
    print("Saving newly created stim file:", output_abs_filepath)

    # Add the metadata to the new audio file (mp3)
    add_audio_metadata(output_abs_filepath, metadata)


def add_triggers_to_video(file_name: str, extension: str, file_paths: namedtuple,
                          sample_rate, video_thumbnails_path: str, use_existing_txt_file=True, plot=False):
    """
    Process a video file, add triggers to its audio, save the video with metadata, and generate a thumbnail.

    :param file_name: (str) Name of the video file.
    :param file_paths: (namedtuple FilePaths) Contains paths:
        - `media_file_path`: Path to the source video without triggers.
        - `stimuli_file_path`: Path where the new stimulus file with triggers will be saved.
        - `trigger_file_path`: Path to save the trigger positions.
    :param sample_rate: (int) Sample rate of the audio in the video.
    :param video_thumbnails_path: (str) Path to save the video thumbnail.
    :param use_existing_txt_file: (bool) If true and a .txt file exists in the output dir, use the saved positions to
        recreate the trigger signal
    :param plot: (bool) If True, plots the audio data.
    """

    # Load video and audio
    video_clip = VideoFileClip(os.path.join(file_paths.source_media_path, file_name + extension))
    audio = video_clip.audio.to_soundarray(fps=sample_rate)

    # If stereo, convert to mono
    if audio.ndim > 1:
        audio = librosa.to_mono(audio.T)
    else:
        audio = audio.T

    # Add triggers
    audio_with_triggers = create_trigger_signal(use_existing_txt_file, audio, sample_rate,
                                                file_name, file_paths.trigger_pos_path)

    # Plot the stereo sound if requested
    if plot:
        plot_stereo_audio(audio_with_triggers.T, sample_rate, file_name)

    # Create a black screen as long as the added silence and concatenate with the original video
    black_screen = ColorClip((video_clip.size), col=(0, 0, 0), duration=SILENCE_DURATION)
    video_clip = concatenate_videoclips([black_screen, video_clip])

    # generate and save thumbnail
    video = video_clip.set_audio(AudioClip.AudioArrayClip(audio_with_triggers, fps=sample_rate))
    thumbnail_time = video.duration / 10
    video.save_frame(os.path.join(video_thumbnails_path, f"{file_name}.jpg"), t=thumbnail_time)

    # Save video
    video.write_videofile(os.path.join(file_paths.stim_with_trigs_path, f"{file_name}.mp4"),
                          bitrate='5000k',
                          write_logfile=False,
                          codec='libx264',
                          audio_codec='aac',
                          temp_audiofile=f'{file_name}-temp-audio.m4a',
                          remove_temp=True,
                          preset='veryfast',
                          logger="bar")

    # Add the metadata to the new video file (mp4)
    add_video_metadata(os.path.join(file_paths.source_media_path, file_name + extension),
                       os.path.join(file_paths.stim_with_trigs_path, f"{file_name}.mp4"),)  # source_media_path, stim_with_trigs_path


def add_audio_metadata(stim_with_trigs_path: str, metadata: dict):
    """
    Add or update the metadata of a media file using the provided metadata information.

    The metadata dictionary can have the following keys: 'title', 'artist', 'album', and 'genre'.
    If a key is not present, its corresponding metadata in the media file will be set to an empty string.

    :param stim_with_trigs_path: Path to the media file for which metadata needs to be updated.
    :param metadata: Dictionary containing the metadata information.
    """

    # Load the stim file with triggers
    stimulus_file = eyed3.load(stim_with_trigs_path)

    # Check if the media file has existing metadata tags
    # If not, initialize a new tag for it
    if stimulus_file.tag is None:
        stimulus_file.initTag()

    # Update the  metadata or set fields to an empty string if not provided
    stimulus_file.tag.title = metadata.get('title', '')
    stimulus_file.tag.artist = metadata.get('artist', '')
    stimulus_file.tag.album = metadata.get('album', '')
    stimulus_file.tag.genre = metadata.get('genre', '')

    # Save the changes made to the metadata
    stimulus_file.tag.save()


def add_video_metadata(abspath_to_original_video_w_metadata, abspath_to_new_video_w_triggers):
    """
    Copies metadata from an original video file to a new video file.

    :param abspath_to_original_video_w_metadata: (str) Path to the original video file with metadata.
    :param abspath_to_new_video_w_triggers: (str) Path to the new video file with triggers.
    """

    # Copy over the metadata from the original video file to a new 'temp' video file
    ffmpeg_args = ['ffmpeg', '-i', abspath_to_original_video_w_metadata, '-i', abspath_to_new_video_w_triggers, '-map_metadata', '0', '-c', 'copy',
                   '-map', '1:v:0', '-map', '1:a:0', '-y', os.path.splitext(abspath_to_new_video_w_triggers)[0] + '_temp' + '.mp4']
    subprocess.check_call(ffmpeg_args)

    # Replace the 'temp' file with the final output file
    os.remove(abspath_to_new_video_w_triggers)
    os.rename(os.path.splitext(abspath_to_new_video_w_triggers)[0] + '_temp' + '.mp4', abspath_to_new_video_w_triggers)


def plot_stereo_audio(stereo_sound, sr, filename):
    fig, (ax1, ax2) = plt.subplots(nrows=2, sharex='all', figsize=[12, 3])
    ax1.plot(np.arange(len(stereo_sound[0])) / sr, stereo_sound[0])
    ax1.set_ylabel('ch1')
    ax2.plot(np.arange(len(stereo_sound[1])) / sr, stereo_sound[1])
    ax2.set_ylabel('ch2')
    plt.xlabel('Time (s)')
    plt.xlim([0, 15])
    plt.suptitle(filename)
    plt.tight_layout()
    plt.show()


def process_media_file(file_name, file_paths, video_thumbnails_path,
                 sample_rate=44100, use_existing_txt_file: bool = True, plot: bool = False):
    """
    Process an audio or video file based on its extension.

    :param file_name: (str) Name of the file.
    :param file_paths: (namedtuple FilePaths) Contains paths:
        `media_file_path`: Path to the source media without triggers.
        `stimuli_file_path`: Path where the new stimulus file with triggers will be saved.
        `trigger_file_path`: Path to save the trigger positions.
    :param video_thumbnails_path: (str) Path to save the video thumbnail if the file is a video.
    :param sample_rate: (int, optional) Sample rate for the audio. Default is 44100.
    :param use_existing_txt_file: (bool, optional) If True and a .txt file already exists in the output dir,
        recreate the trigger signal using the saved positions.
    :param plot: (bool, optional) If True, plots the audio data. Defaults to False.
    """

    # Extract the file extension to determine if it's audio or video
    file_name, extension = os.path.splitext(file_name)
    print(file_name)

    # Check metadata
    try:
        tag = taglib.File(os.path.join(file_paths.source_media_path, file_name + extension))
        artist_list = tag.tags.get("ARTIST")
        metadata = {"title": tag.tags.get("TITLE")[0],
                    "artist": ', '.join(artist_list) if len(artist_list) > 1 else (
                        tag.tags.get("ARTIST")[0] if len(artist_list) == 1 else None),
                    "album": tag.tags.get("ALBUM")[0],
                    "genre": tag.tags.get("GENRE")[0]}
    except Exception as e:
        print(f"Failed to read metadata from {file_paths.source_media_path}: {e}")
        metadata = {}

    # Process audio file
    if extension in ('.mp3', '.wav'):
        add_triggers_to_audio(file_name, extension, file_paths,
                              sample_rate, metadata, use_existing_txt_file, plot=plot)

    # Process video file
    elif extension == '.mp4':
        add_triggers_to_video(file_name, extension, file_paths,
                              sample_rate, video_thumbnails_path, use_existing_txt_file, plot=plot)

    else:
        raise ValueError(f'Currently unsupported file extension: {extension}')


def find_new_stim_and_add_triggers(cortify_media_dir, accepted_formats=('.wav', '.mp3', 'mp4'),
                                   plot=False, overwrite_existing_triggers=False):
    """
    Processes media files in the specified directory, adding trigger signals to them. Depending on whether trigger
    position files (i.e., .txt files) exist or the `overwrite_existing_triggers` flag is set, the function either
    recreates the trigger signals using existing positions or generates new trigger signals.

    The function saves the processed media files to a specified output directory and optionally
    plots the audio with triggers.


        **Logic for overwriting trigger positions:**

    * If the .txt file exists, and you don't want to overwrite it (`overwrite_existing_triggers` = **False**):
        use the trigger positions saved in the existing file to recreate the stim.

    * If the .txt file doesn't exist, or you want to overwrite the existing .txt (`overwrite_existing_triggers` = **True**):
        create a new trigger signal from scratch.

    :param cortify_media_dir: path to the Cortify Media directory
    :param accepted_formats: (tuple) which filename extensions to look for
    :param plot: (bool) if True, plot the audio on ch1 and trigger signal on ch2
    :param overwrite_existing_triggers: (bool) if True and a stim file with triggers already exists in the output dir
        ('Cortify_Media > Add_Triggers > stimuli_with_triggers'), overwrite the existing stim by recreating a trigger
        signal. If True and a .txt file with trigger positions already exists in the output dir
        ('Cortify_Media > Add_Triggers > triggers'), overwrite the saved positions (!) and create a new trigger signal.
        USE WITH CAUTION!
    """

    # Define the FilePaths namedtuple within the function
    FilePaths = namedtuple("FilePaths", ["source_media_path", "stim_with_trigs_path", "trigger_pos_path"])

    triggers_dir = os.path.join(cortify_media_dir, 'Add_Triggers')

    # Set the paths to the input and output folders
    file_paths = FilePaths(
        source_media_path=os.path.join(triggers_dir, 'original_stimuli'),
        stim_with_trigs_path=os.path.join(triggers_dir, 'stimuli_with_triggers'),
        trigger_pos_path=os.path.join(triggers_dir, 'triggers')
    )

    video_thumbnails_path = os.path.join(cortify_media_dir, 'images', 'Video thumbnails')

    # Create the output folders if they don't exist
    os.makedirs(file_paths.stim_with_trigs_path, exist_ok=True)
    os.makedirs(file_paths.trigger_pos_path, exist_ok=True)

    new_media_found = False

    # Loop over all files in the input folder ('Cortify_Media > Add_Triggers > original_stimuli')
    print("Starting to process files...")
    for file_name in os.listdir(file_paths.source_media_path):
        original_file = os.path.join(file_paths.source_media_path, file_name)
        if os.path.isfile(original_file) and (file_name.endswith(accepted_formats)):

            stimuli_output_path = os.path.join(file_paths.stim_with_trigs_path, file_name)

            # get the base name of the output file without the extension
            output_file_basepath = os.path.splitext(stimuli_output_path)[0]
            trigger_file_basepath = os.path.splitext(file_paths.trigger_pos_path)[0]

            # check if a stim file with the same base name already exists in output folder
            # ('Cortify_Media > Add_Triggers > stimuli_with_triggers')
            # if not, or if you want to overwrite the existing file, create a new trigger signal for this file
            if not glob(output_file_basepath + ".*") or overwrite_existing_triggers:

                process_media_file(file_name, file_paths, video_thumbnails_path, plot=plot,
                                   # check if a .txt (trigger positions) with the same base name exists in output folder
                                   # ('Cortify_Media > Add_Triggers > triggers')
                                   # If the .txt file exists and you don't want to overwrite it:
                                   #     use the trigger positions saved in the existing file to recreate the stim
                                   # If the .txt file doesn't exist, or you want to overwrite the existing .txt file:
                                   #     create a new trigger signal
                             use_existing_txt_file=True if (glob(trigger_file_basepath + "_triggers.txt")
                                                            and not overwrite_existing_triggers) else False)

                new_media_found = True

            else:
                print("File already exists in destination folder:", file_name)

    if not new_media_found:
        print("No new media found.")


if __name__ == '__main__':
    find_new_stim_and_add_triggers(cortify_media_dir=r"C:\Users\nadege\Data\CORTIFY\Cortify_Media",
                                   accepted_formats=('.wav', '.mp3', '.mp4'),
                                   plot=True,
                                   overwrite_existing_triggers=False
                                   )

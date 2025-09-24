"""
This code generates a stereo sound file with silence on the first channel and a trigger on the second channel.
Parameters for the sound file and the trigger are defined at the start of the code.

Author: nadège
"""

import os.path as op
import soundfile as sf
import numpy as np


# Trigger parameters
trigger_duration = 0.0035  # in seconds
trigger_amplitude = 1.0  # 0 to 1
trigger_start_time = 0.05  # seconds into the file

# Sound file parameters
sound_duration = 0.5  # in seconds
sample_rate = 44100  # in Hz,
output_path = r"C:\Users\nadege\Projects\Cortify\assets\trigger_new_acquisition_block"
file_name = f"trigger_pause_{int(sound_duration*1000)}ms.wav"


# Calculate the total number of samples for the sound duration
total_samples = int(sound_duration * sample_rate)

# Generate an array for the silent channel
silent_channel = np.zeros(total_samples)

# Generate an array for the click channel
click_channel = np.zeros(total_samples)

# Calculate the start and end samples for the trigger
trigger_start_sample = int(trigger_start_time * sample_rate)
trigger_end_sample = trigger_start_sample + int(trigger_duration * sample_rate)

# Set the trigger samples to the trigger amplitude
click_channel[trigger_start_sample:trigger_end_sample] = trigger_amplitude

# Combine the channels into a stereo sound
stereo_sound = np.array([silent_channel, click_channel]).T

# Write the sound to a .wav file
sf.write(op.join(output_path, file_name), stereo_sound, sample_rate)

print('Created:', file_name, 'in', output_path)


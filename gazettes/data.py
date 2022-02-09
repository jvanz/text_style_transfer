import json
import re
import os
import csv
from urllib.parse import urlparse

from bs4 import BeautifulSoup


def load_gazettes_csv():
    with open("data/gazettes_unix.csv", "r") as csvfile:
        reader = csv.DictReader(csvfile, dialect="unix")
        for row in reader:
            yield row


def load_gazettes_sample():
    with open("data/gazettes_sample.csv", "r") as csvfile:
        reader = csv.DictReader(csvfile, dialect="unix")
        for row in reader:
            file_name_from_url = urlparse(row["file_link"]).path.rsplit("/", 1)[-1]
            row["file_path"] = f"data/files/{file_name_from_url}"
            yield row


def get_file_to_store_extracted_text(file_path: str):
    """Generates the file name used to store the file's content

    :file_path: original file path
    :returns: file path used to store the file's content
    """
    file_name = os.path.basename(os.path.splitext(file_path)[0])
    return f"data/files/{file_name}.xml"


def get_file_to_store_clean_text(file_path: str):
    """Generates the file name used to store the file's content

    :file_path: original file path
    :returns: file path used to store the file's content
    """
    file_name = os.path.basename(os.path.splitext(file_path)[0])
    return f"data/files/{file_name}_text.json"


def load_gazette_text(gazette):
    """Load file with the clean text of the given gazette.

    :gazette: gazette which the user wants to get the text
    :returns: list of the sentences in the text
    """
    with open(get_file_to_store_clean_text(gazette["file_path"]), "r") as text_file:
        return json.load(text_file)
    return []


def is_there_clean_content_file(gazette):
    """Check if there is a file with the clean text from the given gazette.

    :returns: true if the file with the clan text. Otherwise, returns false.
    """
    clean_text_file = get_file_to_store_clean_text(gazette["file_path"])
    return os.path.exists(clean_text_file)


def remove_repeating_whitespaces_and_new_lines(text: str) -> str:
    """Removes repeating new lines and tabular char."""
    return re.sub(r"(\n|\r|\t| ){1,}", " ", text)


def remove_repeating_dashes(text: str) -> str:
    """Removes repeating dashes."""
    return re.sub(r"(-|_|\.){1,}", "", text)


def clean_sentence(sentence: str) -> str:
    """Clean sentence removing unnecessary chars."""
    sentence = remove_repeating_whitespaces_and_new_lines(sentence)
    sentence = remove_repeating_dashes(sentence)
    return sentence.lower()


def clean_gazette_text(content_file: str, clean_gazette_text: str):
    """Clean text from the given gazette's content_file and store the clean text
    in the clean_gazette_text

    :content_file: file with the original gazette's text
    :clean_gazette_text: file where the clean text will be stored

    """
    text = []
    with open(content_file, "r") as file:
        soup = BeautifulSoup(file, features="lxml")
        for sentence in soup.stripped_strings:
            if len(sentence) < 3:
                continue
            text.append(clean_sentence(sentence))
    if len(text) == 0:
        raise Exception(f"Could not get text from {content_file}")
    with open(clean_gazette_text, "w") as clean_text_file:
        json.dump(text, clean_text_file)


def clean_gazette_text_if_necessary(gazette, force_clean=False):
    """Clean gazette's text if necessary or if force_clean is true

    The clean text is stored in a file. If the file exists and the force_clean
    is false, this function does nothing.

    :gazette: info  of the gazette which may be clean
    :force_clean: force reclean the text
    """
    if not is_there_clean_content_file(gazette) or force_clean:
        content_file = get_file_to_store_extracted_text(gazette["file_path"])
        clean_text_file = get_file_to_store_clean_text(gazette["file_path"])
        clean_gazette_text(content_file, clean_text_file)


def sample_gazettes_texts(force_clean=False):
    """
    Walk through the gazettes files and return the preprocessed string.
    """
    for gazette in load_gazettes_sample():
        clean_gazette_text_if_necessary(gazette, force_clean=force_clean)
        text = load_gazette_text(gazette)
        yield gazette, text
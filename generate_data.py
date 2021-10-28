import os


def generate_data(folder_path):
    """
    Function to concatenate all the files in the folder_path and generate a file called data_gen.sql
    """
    # Open the file to write
    with open("data.sql", "w") as f:
        # Loop through all the files in the folder_path
        files = sorted(os.listdir(folder_path), key=lambda x: int(x.split('_')[0]))
        for file in files:
            # Open the file to read
            with open(folder_path + "/" + file, "r") as f1:
                # Write the content of the file to the file to write
                f.write(f1.read())
                # Close the file
                f1.close()
            # Close the file
        f.close()


generate_data('./dummy_data')

# SSH Upload & Download Tools for CloudPanel

This repository contains a collection of Windows Batch scripts designed to automate common tasks when working with servers managed by CloudPanel. These tools simplify the process of uploading/downloading databases and files via SSH and SCP.

## 🚀 Purpose

The main goal of this repository is to provide a quick and interactive way to manage remote server data without manually typing long SSH commands. The scripts use `scp` for file transfers and `ssh` for remote execution.

## 📂 Included Tools

### 1. Database Operations
*   **`Upload_DB.bat`**: 
    *   Allows you to select a local `.sql` or `.sql.gz` file.
    *   Uploads the file to the server.
    *   Automatically restores the database using the provided MySQL credentials.
*   **`Download_DB.bat`**: 
    *   Fetches a list of databases from the remote server.
    *   Allows you to select a database to dump.
    *   Downloads the `.sql.gz` dump to your local machine.

### 2. File Operations
*   **`Upload-Files.bat`**: 
    *   Zips local project files (using `tar`).
    *   Uploads the zip to the server.
    *   Extracts the files into the target directory on the server.
*   **`Download_Files.bat`**: 
    *   Lists directories in the user's `htdocs` folder on the server.
    *   Zips the selected directory on the server.
    *   Downloads the zip file to your local machine.

## 🛠 Prerequisites

1.  **Windows OS**: These are `.bat` files designed for the Windows Command Prompt.
2.  **OpenSSH Client**: Ensure `ssh` and `scp` are available in your PATH (included by default in modern Windows 10/11).
3.  **SSH Access**: You must have SSH access to your CloudPanel server.
4.  **Recommended**: Run `ssh-add` in your terminal or use an SSH key agent to avoid entering your SSH password repeatedly during script execution.

## 🔒 Security Note

*   The `.gitignore` in this repository is configured to exclude sensitive files such as:
    *   SQL database dumps (`*.sql`)
    *   Large project folders (like Laravel apps)
    *   Log files and temporary zips
*   **Always ensure you do not commit actual database credentials or sensitive data.**

## 📖 How to Use

1.  Place the `.bat` files in your local working directory.
2.  Double-click the desired script (e.g., `Upload_DB.bat`).
3.  Follow the interactive prompts to select the server, enter your SSH username, and perform the desired action.

---
*Maintained for easy deployment and backup of CloudPanel-hosted applications.*

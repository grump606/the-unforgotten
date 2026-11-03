# The Unforgotten on a Mac

Instructions to hand to someone who wants to run the game on macOS. The repository is public, so no GitHub account is needed. How the build is made, and what is and is not done, is in [`MACOS.md`](MACOS.md).

Repository: https://github.com/grump606/the-unforgotten

**Requirements:** an Intel Mac on macOS 10.12 or later, or an Apple Silicon Mac (M1 or newer) on macOS 11 or later. The macOS build has not been run on a Mac by its author yet, so please report anything odd (see the end).

## Path A: download the ready-made app (recommended)

1. Go to https://github.com/grump606/the-unforgotten/releases/latest
2. Under **Assets**, download `TheUnforgotten-macOS-<version>.zip` (for example `TheUnforgotten-macOS-0.7.2.zip`). Ignore the `.exe` files, which are for Windows.
3. Open your **Downloads** folder and double-click the zip. It creates **The Unforgotten.app**.
4. Drag **The Unforgotten** into **Applications**.
5. **First launch:** macOS blocks the app because it is not notarized by Apple. This is expected. Use one of these:
   - **System Settings:** double-click the app, and when the warning appears click **Done** (never "Move to Trash"). Open **System Settings > Privacy & Security**, scroll to **Security**, click **Open Anyway** next to "The Unforgotten was blocked", enter your password and click **Open**. On macOS 14 or earlier you can also right-click the app, choose **Open**, and click **Open** again. macOS 15 (Sequoia) removed that shortcut, so use System Settings there.
   - **Terminal (works on every version):** open Terminal and run
     `xattr -dr com.apple.quarantine "/Applications/The Unforgotten.app"`
     then double-click the app as normal.
6. After that it opens normally every time.

## Path B: run it from the source code (optional)

Only needed to look at or modify the project.

1. **Get the code.** Either open Terminal and run `git clone https://github.com/grump606/the-unforgotten.git` (accept the command line tools offer if macOS makes one), or click **Code > Download ZIP** on the repository page and unzip it.
2. **Install Godot 4.7.2.** It must be exactly this version, and the standard edition, not ".NET". Download "4.7.2 stable" for macOS from https://godotengine.org/download/archive/ , unzip it and drag **Godot** into Applications.
3. Open **Godot**. In the Project Manager click **Import**, choose the `project.godot` file in the `the-unforgotten` folder, then **Import & Edit**. The first import takes a few minutes.
4. Press **F5** (or the play button at the top right) to run the game.
5. To build your own `.app`: choose **Project > Export...**, and if it asks, install the 4.7.2 export templates (**Manage Export Templates > Download and Install**). Select the **macOS** preset and click **Export Project**. An app built on your own machine does not trigger the Gatekeeper warning.

## Playing

The game opens on a main menu with **New Journey**, **Continue** (once there is a save), **Exit** and **Sound**. **Escape** pauses during a run. Saves and settings are stored in `~/Library/Application Support/The Unforgotten/`, so deleting the app does not delete progress.

## Updating

The red **Update** button in the main menu's corner means a newer version exists. Clicking it shows a bar with **Download**, which opens the releases page; repeat Path A with the newer zip. Saves carry over. (Path B users can run `git pull` instead.) The in-game updater only installs the Windows version.

## If something goes wrong

- **"The Unforgotten is damaged and can't be opened":** use the Terminal command in step 5.
- **It closes immediately or shows nothing:** run `"/Applications/The Unforgotten.app/Contents/MacOS/The Unforgotten"` in Terminal and send whatever it prints.
- **Check the download:** run `shasum -a 256 ~/Downloads/TheUnforgotten-macOS-<version>.zip` and compare the result with the contents of the `.sha256` file next to the zip on the releases page.
- **Please report:** the window size, fonts, sound, the Escape pause key, and whether saving and **Continue** work after quitting.

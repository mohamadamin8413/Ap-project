import com.google.gson.*;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.text.SimpleDateFormat;
import java.util.Date;

public class RequestHandeler {
    private final Gson gson = new Gson();
    private final UserManager userManager;
    private final MusicManager musicManager;
    private static final String MUSIC_DIR = System.getProperty("user.dir") + File.separator + "musics";

    public RequestHandeler() {
        this.userManager = new UserManager();
        this.musicManager = new MusicManager();
        userManager.setMusicManager(musicManager);
        File musicDir = new File(MUSIC_DIR);
        if (!musicDir.exists()) {
            musicDir.mkdirs();
        }
    }

    public String processRequest(String requestLine) {
        JsonObject response = new JsonObject();
        try {
            JsonObject request = JsonParser.parseString(requestLine).getAsJsonObject();
            String action = request.get("action").getAsString();
            JsonObject data = request.get("data").getAsJsonObject();
            String requestId = request.get("requestId") != null ? request.get("requestId").getAsString() : "";
            response.addProperty("requestId", requestId);

            switch (action) {
                case "register": {
                    String email = data.get("email").getAsString();
                    String username = data.get("username").getAsString();
                    String password = data.get("password").getAsString();
                    boolean registered = userManager.HandelRegister(email, username, password);
                    response.addProperty("status", registered ? "success" : "error");
                    response.addProperty("message", registered ? "User registered" : "Email already exists");
                    if (registered) {
                        response.add("data", gson.toJsonTree(userManager.getUserByEmail(email)));
                    }
                    break;
                }
                case "login": {
                    String email = data.get("email").getAsString();
                    String password = data.get("password").getAsString();
                    boolean loggedIn = userManager.HandelLogin(email, password);
                    response.addProperty("status", loggedIn ? "success" : "error");
                    response.addProperty("message", loggedIn ? "Login successful" : "Invalid credentials");
                    if (loggedIn) {
                        response.add("data", gson.toJsonTree(userManager.getUserByEmail(email)));
                    }
                    break;
                }
                case "get_user": {
                    String email = data.get("email").getAsString();
                    User user = userManager.getUserByEmail(email);
                    if (user != null) {
                        JsonObject userJson = new JsonObject();
                        userJson.addProperty("email", user.getEmail());
                        userJson.addProperty("username", user.getUsername());
                        userJson.addProperty("allowSharing", user.isAllowSharing());
                        response.add("data", userJson);
                        response.addProperty("status", "success");
                        response.addProperty("message", "User retrieved");
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "User not found");
                    }
                    break;
                }
                case "update_user": {
                    String email = data.get("email").getAsString();
                    String username = data.get("username").getAsString();
                    String password = data.get("password").getAsString();
                    boolean updated = userManager.updateUser(email, username, password);
                    response.addProperty("status", updated ? "success" : "error");
                    response.addProperty("message", updated ? "User updated" : "Update failed");
                    if (updated) {
                        response.add("data", gson.toJsonTree(userManager.getUserByEmail(email)));
                    }
                    break;
                }
                case "delete_user": {
                    String email = data.get("email").getAsString();
                    boolean deleted = userManager.deleteUser(email);
                    response.addProperty("status", deleted ? "success" : "error");
                    response.addProperty("message", deleted ? "User deleted" : "User not found");
                    break;
                }
                case "like_music": {
                    String email = data.get("email").getAsString();
                    String musicName = data.get("music_name").getAsString().trim();
                    User user = userManager.getUserByEmail(email);
                    Music music = userManager.findMusicEverywhere(musicName, user);
                    if (music == null) {
                        response.addProperty("status", "error");
                        response.addProperty("message", "Music not found");
                        break;
                    }
                    boolean isAlreadyLiked = user.getLikedMusics().stream()
                            .anyMatch(m -> m.getTitle().trim().equalsIgnoreCase(musicName));
                    if (isAlreadyLiked) {
                        response.addProperty("status", "error");
                        response.addProperty("message", "Music already liked");
                        break;
                    }
                    boolean liked = user.likeMusic(music);
                    if (liked) {
                        music.addLike();
                        DatabaseManager.saveUsers(userManager.getUsers());
                        response.addProperty("status", "success");
                        response.addProperty("message", "Music liked successfully");
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "Failed to like music");
                    }
                    break;
                }
                case "unlike_music": {
                    String email = data.get("email").getAsString();
                    String musicName = data.get("music_name").getAsString().trim();
                    User user = userManager.getUserByEmail(email);
                    Music music = userManager.findMusicEverywhere(musicName, user);
                    boolean isLiked = user.getLikedMusics().stream()
                            .anyMatch(m -> m.getTitle().trim().equalsIgnoreCase(musicName));
                    if (!isLiked) {
                        response.addProperty("status", "error");
                        response.addProperty("message", "Music not liked");
                        break;
                    }
                    boolean unliked = user.unlikeMusic(musicName);
                    if (unliked) {
                        music.removeLike();
                        DatabaseManager.saveUsers(userManager.getUsers());
                        response.addProperty("status", "success");
                        response.addProperty("message", "Music unliked successfully");
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "Failed to unlike music");
                    }
                    break;
                }
                case "list_liked_music": {
                    String email = data.get("email").getAsString();
                    User user = userManager.getUserByEmail(email);
                    if (user != null) {
                        JsonArray musicArray = new JsonArray();
                        for (Music music : user.getLikedMusics()) {
                            JsonObject musicJson = createMusicJson(music);
                            String coverFileName = music.getTitle() + "-cover.jpg";
                            File coverFile = new File(MUSIC_DIR + File.separator + coverFileName);
                            if (coverFile.exists()) {
                                byte[] coverBytes = Files.readAllBytes(coverFile.toPath());
                                musicJson.addProperty("cover", Base64.getEncoder().encodeToString(coverBytes));
                            }
                            musicArray.add(musicJson);
                        }
                        response.add("data", musicArray);
                        response.addProperty("status", "success");
                        response.addProperty("message", "Liked music retrieved");
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "User not found");
                    }
                    break;
                }
                case "share_playlist": {
                    String email = data.get("email").getAsString();
                    String targetEmail = data.get("target_email").getAsString();
                    String playlistName = data.get("playlist_name").getAsString();
                    User user = userManager.getUserByEmail(email);
                    User targetUser = userManager.getUserByEmail(targetEmail);
                    PlayList playlist = user != null ? user.findPlaylistByName(playlistName) : null;
                    if (user != null && targetUser != null && playlist != null && playlist.getCreatorEmail().equals(email)) {
                        if (targetUser.isAllowSharing()) {
                            PlayList shared = new PlayList(playlist.getName(), targetEmail);
                            for (Music music : playlist.getMusics()) {
                                boolean addedToUser = targetUser.addUserMusic(music);
                                if (addedToUser) {
                                    shared.addMusic(music);
                                } else {
                                    System.out.println("Music " + music.getTitle() + " already exists in target user's library");
                                }
                            }
                            targetUser.addPlaylist(shared);
                            DatabaseManager.saveUsers(userManager.getUsers());
                            response.addProperty("status", "success");
                            response.addProperty("message", "Playlist shared with " + shared.getMusics().size() + " songs");
                        } else {
                            response.addProperty("status", "error");
                            response.addProperty("message", "Target user has disabled sharing");
                        }
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "Playlist, user, or target user not found, or user is not the creator");
                    }
                    break;
                }
                case "list_users": {
                    List<User> users = userManager.getUsers();
                    JsonArray usersArray = new JsonArray();
                    for (User user : users) {
                        if (user.isAllowSharing()) {
                            JsonObject userJson = new JsonObject();
                            userJson.addProperty("email", user.getEmail());
                            userJson.addProperty("username", user.getUsername());
                            usersArray.add(userJson);
                        }
                    }
                    response.add("data", usersArray);
                    response.addProperty("status", "success");
                    response.addProperty("message", "Users retrieved");
                    break;
                }
                case "share_music": {
                    String email = data.get("email").getAsString();
                    String targetEmail = data.get("target_email").getAsString();
                    String musicName = data.get("music_name").getAsString().trim();
                    User user = userManager.getUserByEmail(email);
                    User targetUser = userManager.getUserByEmail(targetEmail);
                    Music music = userManager.findMusicEverywhere(musicName, user);
                    if (user != null && targetUser != null && music != null) {
                        if (targetUser.isAllowSharing()) {
                            boolean added = targetUser.addUserMusic(music);
                            if (added) {
                                DatabaseManager.saveUsers(userManager.getUsers());
                                JsonObject dataResponse = createMusicJson(music);
                                response.add("data", dataResponse);
                                response.addProperty("status", "success");
                                response.addProperty("message", "Music shared successfully");
                            } else {
                                response.addProperty("status", "success");
                                response.addProperty("message", "Music already exists in target user's library, no action taken");
                            }
                        } else {
                            response.addProperty("status", "error");
                            response.addProperty("message", "Target user has disabled sharing");
                        }
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "User, target user, or music not found");
                    }
                    break;
                }
                case "add_local_music": {
                    String email = data.get("email").getAsString();
                    String title = data.get("title").getAsString();
                    String artist = data.get("artist").getAsString();
                    String base64File = data.get("file").getAsString();
                    String base64Cover = data.has("cover") ? data.get("cover").getAsString() : null;
                    User user = userManager.getUserByEmail(email);
                    if (user != null) {
                        boolean songExists = user.getUserMusics().stream()
                                .anyMatch(m -> m.getTitle().trim().equalsIgnoreCase(title.trim()) && m.getArtist().trim().equalsIgnoreCase(artist.trim()));
                        if (songExists) {
                            response.addProperty("status", "error");
                            response.addProperty("message", "This song already exists in your library");
                            break;
                        }
                        String musicFileName = title + ".mp3";
                        String musicFilePath = MUSIC_DIR + File.separator + musicFileName;
                        byte[] fileBytes = Base64.getDecoder().decode(base64File);
                        try (FileOutputStream fos = new FileOutputStream(musicFilePath)) {
                            fos.write(fileBytes);
                        }
                        String coverFileName = null;
                        if (base64Cover != null && !base64Cover.isEmpty()) {
                            coverFileName = title + "-cover.jpg";
                            String coverFilePath = MUSIC_DIR + File.separator + coverFileName;
                            byte[] coverBytes = Base64.getDecoder().decode(base64Cover);
                            try (FileOutputStream fos = new FileOutputStream(coverFilePath)) {
                                fos.write(coverBytes);
                            }
                        }
                        Music music = new Music(title, artist, musicFileName, email);
                        user.addUserMusic(music);
                        DatabaseManager.saveUsers(userManager.getUsers());
                        JsonObject dataResponse = createMusicJson(music);
                        if (coverFileName != null) {
                            File coverFile = new File(MUSIC_DIR + File.separator + coverFileName);
                            if (coverFile.exists()) {
                                byte[] coverBytes = Files.readAllBytes(coverFile.toPath());
                                dataResponse.addProperty("cover", Base64.getEncoder().encodeToString(coverBytes));
                            }
                        }
                        response.add("data", dataResponse);
                        response.addProperty("status", "success");
                        response.addProperty("message", "Local music added successfully" +
                                (coverFileName != null ? " with cover" : ""));
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "User not found");
                    }
                    break;
                }
                case "add_server_music": {
                    String email = data.get("email").getAsString();
                    String musicName = data.get("music_name").getAsString().trim();
                    User user = userManager.getUserByEmail(email);
                    Music music = musicManager.findByName(musicName);
                    if (user != null && music != null) {
                        boolean added = user.addUserMusic(music);
                        if (added) {
                            DatabaseManager.saveUsers(userManager.getUsers());
                            response.addProperty("status", "success");
                            response.addProperty("message", "Server music added successfully");
                        } else {
                            response.addProperty("status", "error");
                            response.addProperty("message", "Music already in user's music list");
                        }
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "User or music not found");
                    }
                    break;
                }
                case "list_user_musics": {
                    String email = data.get("email").getAsString();
                    User user = userManager.getUserByEmail(email);
                    if (user != null) {
                        JsonArray musicArray = new JsonArray();
                        for (Music music : user.getUserMusics()) {
                            JsonObject musicJson = createMusicJson(music);
                            String coverFileName = music.getTitle() + "-cover.jpg";
                            File coverFile = new File(MUSIC_DIR + File.separator + coverFileName);
                            if (coverFile.exists()) {
                                byte[] coverBytes = Files.readAllBytes(coverFile.toPath());
                                musicJson.addProperty("cover", Base64.getEncoder().encodeToString(coverBytes));
                            }
                            musicArray.add(musicJson);
                        }
                        response.add("data", musicArray);
                        response.addProperty("status", "success");
                        response.addProperty("message", "User musics retrieved");
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "User not found");
                    }
                    break;
                }
                case "list_server_musics": {
                    List<Music> serverMusics = musicManager.getServerMusics();
                    JsonArray musicArray = new JsonArray();
                    for (Music music : serverMusics) {
                        JsonObject musicJson = createMusicJson(music);
                        String coverFileName = music.getTitle() + "-cover.jpg";
                        File coverFile = new File(MUSIC_DIR + File.separator + coverFileName);
                        if (coverFile.exists()) {
                            byte[] coverBytes = Files.readAllBytes(coverFile.toPath());
                            musicJson.addProperty("cover", Base64.getEncoder().encodeToString(coverBytes));
                        }
                        musicArray.add(musicJson);
                    }
                    response.add("data", musicArray);
                    response.addProperty("status", "success");
                    response.addProperty("message", "Server musics retrieved");
                    break;
                }
                case "download_music": {
                    String musicName = data.get("name").getAsString().trim();
                    String email = data.has("email") ? data.get("email").getAsString() : "";
                    User user = email.isEmpty() ? null : userManager.getUserByEmail(email);
                    Music music = musicManager.findByName(musicName);
                    if (music == null && user != null) {
                        music = user.getUserMusics().stream()
                                .filter(m -> m.getTitle().trim().equalsIgnoreCase(musicName))
                                .findFirst()
                                .orElse(null);
                    }
                    if (music != null) {
                        File file = new File(MUSIC_DIR + File.separator + music.getFilePath());
                        if (file.exists()) {
                            try {
                                byte[] fileBytes = Files.readAllBytes(file.toPath());
                                String base64File = Base64.getEncoder().encodeToString(fileBytes);
                                JsonObject dataResponse = new JsonObject();
                                dataResponse.addProperty("file", base64File);
                                String coverFileName = music.getTitle() + "-cover.jpg";
                                File coverFile = new File(MUSIC_DIR + File.separator + coverFileName);
                                if (coverFile.exists()) {
                                    byte[] coverBytes = Files.readAllBytes(coverFile.toPath());
                                    dataResponse.addProperty("cover", Base64.getEncoder().encodeToString(coverBytes));
                                }
                                response.add("data", dataResponse);
                                response.addProperty("status", "success");
                                response.addProperty("message", "Music file retrieved");
                            } catch (IOException e) {
                                response.addProperty("status", "error");
                                response.addProperty("message", "Error reading music file: " + e.getMessage());
                            }
                        } else {
                            response.addProperty("status", "error");
                            response.addProperty("message", "Music file not found on server");
                        }
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "Music not found");
                    }
                    break;
                }
                case "create_playlist": {
                    String email = data.get("email").getAsString();
                    String name = data.get("name").getAsString();
                    User user = userManager.getUserByEmail(email);
                    if (user != null) {
                        PlayList existingPlaylist = user.findPlaylistByName(name);
                        if (existingPlaylist == null) {
                            PlayList playlist = new PlayList(name.trim(), email);
                            userManager.addPlaylistToUser(email, playlist);
                            JsonObject dataResponse = new JsonObject();
                            dataResponse.addProperty("id", playlist.getId());
                            dataResponse.addProperty("name", playlist.getName());
                            dataResponse.addProperty("creatorEmail", playlist.getCreatorEmail());
                            JsonArray musicsArray = new JsonArray();
                            dataResponse.add("musics", musicsArray);
                            response.add("data", dataResponse);
                            response.addProperty("status", "success");
                            response.addProperty("message", "Playlist created successfully");
                        } else {
                            response.addProperty("status", "error");
                            response.addProperty("message", "Playlist name already exists for this user");
                        }
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "User not found");
                    }
                    break;
                }
                case "delete_playlist": {
                    String email = data.get("email").getAsString();
                    String playlistName = data.get("playlist_name").getAsString();
                    User user = userManager.getUserByEmail(email);
                    PlayList playlist = user != null ? user.findPlaylistByName(playlistName) : null;
                    if (user != null && playlist != null && playlist.getCreatorEmail().equals(email)) {
                        boolean removed = userManager.removePlaylistFromUser(email, playlistName);
                        if (removed) {
                            response.addProperty("status", "success");
                            response.addProperty("message", "Playlist deleted successfully");
                        } else {
                            response.addProperty("status", "error");
                            response.addProperty("message", "Playlist not found");
                        }
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "User or playlist not found, or user is not the creator");
                    }
                    break;
                }
                case "list_user_playlists": {
                    String email = data.get("email").getAsString();
                    User user = userManager.getUserByEmail(email);
                    if (user != null) {
                        List<PlayList> userPlaylists = userManager.getUserPlaylists(email);
                        JsonArray playlistsArray = new JsonArray();
                        for (PlayList playlist : userPlaylists) {
                            JsonObject playlistJson = new JsonObject();
                            playlistJson.addProperty("id", playlist.getId());
                            playlistJson.addProperty("name", playlist.getName());
                            playlistJson.addProperty("creatorEmail", playlist.getCreatorEmail());
                            JsonArray musicsArray = new JsonArray();
                            for (Music music : playlist.getMusics()) {
                                JsonObject musicJson = createMusicJson(music);
                                String coverFileName = music.getTitle() + "-cover.jpg";
                                File coverFile = new File(MUSIC_DIR + File.separator + coverFileName);
                                if (coverFile.exists()) {
                                    try {
                                        byte[] coverBytes = Files.readAllBytes(coverFile.toPath());
                                        musicJson.addProperty("cover", Base64.getEncoder().encodeToString(coverBytes));
                                    } catch (IOException e) {
                                        System.out.println("Error reading cover file for music " + music.getTitle() + ": " + e.getMessage());
                                    }
                                }
                                musicsArray.add(musicJson);
                            }
                            playlistJson.add("musics", musicsArray);
                            playlistsArray.add(playlistJson);
                        }
                        response.add("data", playlistsArray);
                        response.addProperty("status", "success");
                        response.addProperty("message", "User playlists retrieved");
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "User not found");
                    }
                    break;
                }
                case "add_music_to_playlist": {
                    String email = data.get("email").getAsString();
                    String playlistName = data.get("playlist_name").getAsString().trim();
                    int musicId = data.get("music_id").getAsInt();
                    User user = userManager.getUserByEmail(email);
                    PlayList playlist = user != null ? user.findPlaylistByName(playlistName) : null;
                    if (user == null || playlist == null || !playlist.getCreatorEmail().equals(email)) {
                        response.addProperty("status", "error");
                        response.addProperty("message", "User or playlist not found, or user is not the creator");
                        break;
                    }
                    Music music = null;
                    music = user.getUserMusics().stream()
                            .filter(m -> m.getId() == musicId)
                            .findFirst()
                            .orElse(null);
                    if (music == null) {
                        music = musicManager.getServerMusics().stream()
                                .filter(m -> m.getId() == musicId)
                                .findFirst()
                                .orElse(null);
                    }
                    if (music == null) {
                        for (User otherUser : userManager.getUsers()) {
                            if (otherUser.isAllowSharing() && !otherUser.getEmail().equals(email)) {
                                music = otherUser.getUserMusics().stream()
                                        .filter(m -> m.getId() == musicId)
                                        .findFirst()
                                        .orElse(null);
                                if (music != null) break;
                            }
                        }
                    }
                    if (music == null) {
                        response.addProperty("status", "error");
                        response.addProperty("message", "Music not found");
                        break;
                    }
                    boolean alreadyInPlaylist = playlist.getMusics().stream()
                            .anyMatch(m -> m.getId() == musicId);
                    if (alreadyInPlaylist) {
                        response.addProperty("status", "error");
                        response.addProperty("message", "Music already in playlist");
                        break;
                    }
                    boolean added = playlist.addMusic(music);
                    if (added) {
                        DatabaseManager.saveUsers(userManager.getUsers());
                        JsonObject playlistJson = new JsonObject();
                        playlistJson.addProperty("id", playlist.getId());
                        playlistJson.addProperty("name", playlist.getName());
                        playlistJson.addProperty("creatorEmail", playlist.getCreatorEmail());
                        JsonArray musicsArray = new JsonArray();
                        for (Music m : playlist.getMusics()) {
                            JsonObject musicJson = createMusicJson(m);
                            String coverFileName = m.getTitle() + "-cover.jpg";
                            File coverFile = new File(MUSIC_DIR + File.separator + coverFileName);
                            if (coverFile.exists()) {
                                try {
                                    byte[] coverBytes = Files.readAllBytes(coverFile.toPath());
                                    musicJson.addProperty("cover", Base64.getEncoder().encodeToString(coverBytes));
                                } catch (IOException e) {
                                    System.out.println("Error reading cover file for music " + m.getTitle() + ": " + e.getMessage());
                                }
                            }
                            musicsArray.add(musicJson);
                        }
                        playlistJson.add("musics", musicsArray);
                        response.add("data", playlistJson);
                        response.addProperty("status", "success");
                        response.addProperty("message", "Music added to playlist successfully");
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "Failed to add music to playlist");
                    }
                    break;
                }
                case "remove_music_from_playlist": {
                    String email = data.get("email").getAsString();
                    String playlistName = data.get("playlist_name").getAsString().trim();
                    int musicId = data.get("music_id").getAsInt();
                    User user = userManager.getUserByEmail(email);
                    PlayList playlist = user != null ? user.findPlaylistByName(playlistName) : null;
                    if (user == null || playlist == null || !playlist.getCreatorEmail().equals(email)) {
                        response.addProperty("status", "error");
                        response.addProperty("message", "User or playlist not found, or user is not the creator");
                        break;
                    }
                    boolean musicExists = playlist.getMusics().stream()
                            .anyMatch(m -> m.getId() == musicId);
                    if (!musicExists) {
                        response.addProperty("status", "error");
                        response.addProperty("message", "Music not found in playlist");
                        break;
                    }

                    boolean removed = playlist.removeMusicById(musicId);
                    if (removed) {
                        DatabaseManager.saveUsers(userManager.getUsers());

                        JsonObject playlistJson = new JsonObject();
                        playlistJson.addProperty("id", playlist.getId());
                        playlistJson.addProperty("name", playlist.getName());
                        playlistJson.addProperty("creatorEmail", playlist.getCreatorEmail());
                        JsonArray musicsArray = new JsonArray();
                        for (Music m : playlist.getMusics()) {
                            JsonObject musicJson = createMusicJson(m);
                            String coverFileName = m.getTitle() + "-cover.jpg";
                            File coverFile = new File(MUSIC_DIR + File.separator + coverFileName);
                            if (coverFile.exists()) {
                                try {
                                    byte[] coverBytes = Files.readAllBytes(coverFile.toPath());
                                    musicJson.addProperty("cover", Base64.getEncoder().encodeToString(coverBytes));
                                } catch (IOException e) {
                                    System.out.println("Error reading cover file for music " + m.getTitle() + ": " + e.getMessage());
                                }
                            }
                            musicsArray.add(musicJson);
                        }
                        playlistJson.add("musics", musicsArray);
                        response.add("data", playlistJson);
                        response.addProperty("status", "success");
                        response.addProperty("message", "Music removed from playlist successfully");
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "Failed to remove music from playlist");
                    }
                    break;
                }
                case "remove_user_music": {
                    String email = data.get("email").getAsString();
                    String musicName = data.get("music_name").getAsString().trim();
                    User user = userManager.getUserByEmail(email);
                    if (user != null) {
                        boolean removed = user.removeUserMusic(musicName);
                        if (removed) {
                            user.unlikeMusic(musicName);
                            List<PlayList> playlists = user.getPlaylists();
                            for (PlayList playlist : playlists) {
                                boolean removedFromPlaylist = playlist.removeMusic(musicName);
                                if (removedFromPlaylist) {
                                    System.out.println("Removed music " + musicName + " from playlist " + playlist.getName());
                                }
                            }
                            DatabaseManager.saveUsers(userManager.getUsers());
                            response.addProperty("status", "success");
                            response.addProperty("message", "Music removed from user, liked list, and playlists successfully");
                        } else {
                            response.addProperty("status", "error");
                            response.addProperty("message", "Music not found in user's list");
                        }
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "User not found");
                    }
                    break;
                }
                case "toggle_sharing": {
                    String email = data.get("email").getAsString();
                    boolean allowSharing = data.get("allow_sharing").getAsBoolean();
                    User user = userManager.getUserByEmail(email);
                    if (user != null) {
                        user.setAllowSharing(allowSharing);
                        DatabaseManager.saveUsers(userManager.getUsers());
                        response.addProperty("status", "success");
                        response.addProperty("message", "Sharing settings updated");
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "User not found");
                    }
                    break;
                }
                case "get_music_by_id": {
                    int musicId = data.get("id").getAsInt();
                    String email = data.get("email").getAsString();
                    User user = userManager.getUserByEmail(email);
                    Music music = null;
                    if (user != null) {
                        music = user.getUserMusics().stream()
                                .filter(m -> m.getId() == musicId)
                                .findFirst()
                                .orElse(null);
                    }
                    if (music == null) {
                        for (User u : userManager.getUsers()) {
                            music = u.getUserMusics().stream()
                                    .filter(m -> m.getId() == musicId)
                                    .findFirst()
                                    .orElse(null);
                            if (music != null) break;
                        }
                    }
                    if (music == null) {
                        music = musicManager.getServerMusics().stream()
                                .filter(m -> m.getId() == musicId)
                                .findFirst()
                                .orElse(null);
                    }
                    if (music != null) {
                        JsonObject musicJson = createMusicJson(music);
                        String coverFileName = music.getTitle() + "-cover.jpg";
                        File coverFile = new File(MUSIC_DIR + File.separator + coverFileName);
                        if (coverFile.exists()) {
                            try {
                                byte[] coverBytes = Files.readAllBytes(coverFile.toPath());
                                musicJson.addProperty("cover", Base64.getEncoder().encodeToString(coverBytes));
                            } catch (IOException e) {
                                System.out.println("Error reading cover file for music " + music.getTitle() + ": " + e.getMessage());
                            }
                        }
                        response.add("data", musicJson);
                        response.addProperty("status", "success");
                        response.addProperty("message", "Music retrieved");
                    } else {
                        response.addProperty("status", "error");
                        response.addProperty("message", "Music not found");
                    }
                    break;
                }
                default: {
                    response.addProperty("status", "error");
                    response.addProperty("message", "Unknown action");
                    break;
                }
            }
        } catch (JsonParseException e) {
            response.addProperty("status", "error");
            response.addProperty("message", "Invalid JSON format");
            System.out.println("Invalid JSON: " + e.getMessage());
        } catch (Exception e) {
            response.addProperty("status", "error");
            response.addProperty("message", "Server error: " + e.getMessage());
            System.out.println("Server error: " + e.getMessage());
        }
        String responseString = response.toString();
        System.out.println("Sending response: " + responseString);
        return responseString;
    }

    private JsonObject createMusicJson(Music music) {
        JsonObject musicJson = new JsonObject();
        musicJson.addProperty("id", music.getId());
        musicJson.addProperty("title", music.getTitle());
        musicJson.addProperty("artist", music.getArtist());
        musicJson.addProperty("filePath", music.getFilePath());
        musicJson.addProperty("uploaderEmail", music.getUploaderEmail());
        musicJson.addProperty("addedAt", new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss").format(new Date()));
        return musicJson;
    }
}
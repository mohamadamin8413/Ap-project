import java.util.ArrayList;
import java.util.List;
import java.io.*;

public class User {
    private static long lastId = loadLastId("user_last_id.txt");
    private final long id;
    private String username;
    private String password;
    private String email;
    private List<Music> likedMusics;
    private List<Music> userMusics;
    private boolean allowSharing;
    private List<PlayList> playlists;

    public User(String username, String password, String email) {
        this.id = ++lastId;
        saveLastId("user_last_id.txt", lastId);
        this.username = username;
        this.password = password;
        this.email = email;
        this.likedMusics = new ArrayList<>();
        this.userMusics = new ArrayList<>();
        this.allowSharing = true;
        this.playlists = new ArrayList<>();
    }

    public boolean unlikeMusicById(long musicId) {
        for (Music music : likedMusics) {
            if (music.getId() == musicId) {
                likedMusics.remove(music);
                return true;
            }
        }
        return false;
    }

    private static long loadLastId(String filename) {
        try {
            File file = new File(filename);
            if (file.exists()) {
                BufferedReader reader = new BufferedReader(new FileReader(file));
                String line = reader.readLine();
                reader.close();
                if (line != null && !line.trim().isEmpty()) {
                    return Long.parseLong(line.trim());
                }
            }
        } catch (IOException | NumberFormatException e) {
            e.printStackTrace();
        }
        return 0;
    }

    private static void saveLastId(String filename, long id) {
        try {
            BufferedWriter writer = new BufferedWriter(new FileWriter(filename));
            writer.write(String.valueOf(id));
            writer.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public long getId() { return id; }
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    public String getPassword() { return password; }
    public String getEmail() { return email; }
    public List<Music> getLikedMusics() { return likedMusics; }
    public List<Music> getUserMusics() { return userMusics; }
    public boolean isAllowSharing() { return allowSharing; }
    public void setEmail(String email) { this.email = email; }
    public void setPassword(String password) { this.password = password; }
    public void setAllowSharing(boolean allowSharing) { this.allowSharing = allowSharing; }

    public boolean likeMusic(Music music) {
        if (!likedMusics.contains(music)) {
            likedMusics.add(music);
            return true;
        }
        return false;
    }

    public boolean addUserMusic(Music music) {
        if (music != null && !userMusics.stream().anyMatch(m -> m.getTitle().equalsIgnoreCase(music.getTitle()) && m.getArtist().equalsIgnoreCase(music.getArtist()))) {
            Music musicCopy = new Music(music.getTitle(), music.getArtist(), music.getFilePath(), music.getUploaderEmail());
            userMusics.add(musicCopy);
            return true;
        }
        return false;
    }

    public boolean unlikeMusic(String musicName) {
        return likedMusics.removeIf(m -> m.getTitle().equals(musicName));
    }
    public boolean removeUserMusic(String musicName) {
        return userMusics.removeIf(m -> m.getTitle().equals(musicName));
    }

    public List<PlayList> getPlaylists() {
        return playlists;
    }
    public void addPlaylist(PlayList playlist) {
        if (playlist != null && findPlaylistByName(playlist.getName()) == null) {
            playlists.add(playlist);
        }
    }
    public boolean removePlaylist(String playlistName) {
        return playlists.removeIf(p -> p.getName().equalsIgnoreCase(playlistName));
    }
    public PlayList findPlaylistByName(String name) {
        if (name != null) {
            for (PlayList p : playlists) {
                if (p.getName().equalsIgnoreCase(name)) {
                    return p;
                }
            }
        }
        return null;
    }
}
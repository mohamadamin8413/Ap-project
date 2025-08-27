import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class UserManager {
    private static final String DB_DIR = System.getProperty("user.dir") + File.separator + "db";
    private static final String USERS_FILE = DB_DIR + File.separator + "users.json";
    private List<User> users;
    private MusicManager musicManager;

    public UserManager() {
        users = Collections.synchronizedList(new ArrayList<>());
        users.addAll(DatabaseManager.loadUsers());
    }

    public void setMusicManager(MusicManager musicManager) {
        this.musicManager = musicManager;
    }

    public List<User> getUsers() {
        synchronized (users) {
            return new ArrayList<>(users);
        }
    }

    public boolean HandelLogin(String email, String password) {
        if (email != null && password != null) {
            synchronized (users) {
                for (User user : users) {
                    if (user.getEmail().equalsIgnoreCase(email) && user.getPassword().equals(password)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    public boolean HandelRegister(String email, String username, String password) {
        if (email != null && username != null && password != null) {
            synchronized (users) {
                for (User user : users) {
                    if (user.getEmail().equalsIgnoreCase(email)) {
                        System.out.println("Email already exists: " + email);
                        return false;
                    }
                }
                User user = new User(username, password, email);
                users.add(user);
                DatabaseManager.saveUsers(users);
                return true;
            }
        }
        return false;
    }

    public User getUserByEmail(String email) {
        if (email != null) {
            synchronized (users) {
                for (User user : users) {
                    if (user.getEmail().equalsIgnoreCase(email)) {
                        return user;
                    }
                }
            }
        }
        return null;
    }

    public boolean addPlaylistToUser(String email, PlayList playlist) {
        User user = getUserByEmail(email);
        if (user != null && playlist != null) {
            if (user.findPlaylistByName(playlist.getName()) == null) {
                user.addPlaylist(playlist);
                DatabaseManager.saveUsers(users);
                return true;
            }
        }
        return false;
    }

    public boolean removePlaylistFromUser(String email, String playlistName) {
        User user = getUserByEmail(email);
        if (user != null) {
            boolean removed = user.removePlaylist(playlistName);
            if (removed) {
                DatabaseManager.saveUsers(users);
            }
            return removed;
        }
        return false;
    }

    public List<PlayList> getUserPlaylists(String email) {
        User user = getUserByEmail(email);
        if (user != null) {
            return user.getPlaylists();
        }
        return new ArrayList<>();
    }

    public boolean deleteUser(String email) {
        if (email != null) {
            synchronized (users) {
                boolean removed = users.removeIf(u -> u.getEmail().equalsIgnoreCase(email));
                if (removed) {
                    DatabaseManager.saveUsers(users);
                }
                return removed;
            }
        }
        return false;
    }

    public boolean updateUser(String email, String username, String password) {
        if (email != null && username != null && password != null) {
            synchronized (users) {
                for (User user : users) {
                    if (user.getEmail().equalsIgnoreCase(email)) {
                        user.setEmail(email);
                        user.setPassword(password);
                        user.setUsername(username);
                        DatabaseManager.saveUsers(users);
                        return true;
                    }
                }
            }
        }
        return false;
    }

    public Music findMusicEverywhere(String musicName, User user) {
        for (Music music : musicManager.getServerMusics()) {
            if (music.getTitle().equals(musicName)) {
                return music;
            }
        }

        for (Music music : user.getUserMusics()) {
            if (music.getTitle().equals(musicName)) {
                return music;
            }
        }

        for (Music music : user.getLikedMusics()) {
            if (music.getTitle().equals(musicName)) {
                return music;
            }
        }

        return null;
    }

    public Music findMusicById(long musicId, User user) {
        for (Music music : musicManager.getServerMusics()) {
            if (music.getId() == musicId) {
                return music;
            }
        }

        for (Music music : user.getUserMusics()) {
            if (music.getId() == musicId) {
                return music;
            }
        }

        for (Music music : user.getLikedMusics()) {
            if (music.getId() == musicId) {
                return music;
            }
        }

        return null;
    }
}
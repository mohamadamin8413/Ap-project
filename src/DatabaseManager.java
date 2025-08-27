import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import java.io.*;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;

public class DatabaseManager {
    private static final String DB_DIR = System.getProperty("user.dir") + File.separator + "db";
    private static final String MUSIC_FILE = DB_DIR + File.separator + "musics.json";
    private static final String SERVER_MUSIC_FILE = DB_DIR + File.separator + "server_musics.json";
    private static final String USERS_FILE = DB_DIR + File.separator + "users.json";
    private static final Gson gson = new Gson();

    static {
        File dbDir = new File(DB_DIR);
        if (!dbDir.exists()) {
            dbDir.mkdirs();
        }
    }

    public static void saveMusics(List<Music> musics) {
        try (Writer writer = new FileWriter(MUSIC_FILE)) {
            gson.toJson(musics, writer);
        } catch (IOException e) {
            System.out.println("Error saving musics: " + e.getMessage());
        }
    }

    public static List<Music> loadMusics() {
        try (Reader reader = new FileReader(MUSIC_FILE)) {
            Type musicListType = new TypeToken<List<Music>>(){}.getType();
            List<Music> musics = gson.fromJson(reader, musicListType);
            return musics != null ? musics : new ArrayList<>();
        } catch (FileNotFoundException e) {
            return new ArrayList<>();
        } catch (IOException e) {
            System.out.println("Error loading musics: " + e.getMessage());
            return new ArrayList<>();
        }
    }


    public static List<Music> loadServerMusics() {
        try (Reader reader = new FileReader(SERVER_MUSIC_FILE)) {
            Type musicListType = new TypeToken<List<Music>>(){}.getType();
            List<Music> serverMusics = gson.fromJson(reader, musicListType);
            return serverMusics != null ? serverMusics : new ArrayList<>();
        } catch (FileNotFoundException e) {
            return new ArrayList<>();
        } catch (IOException e) {
            System.out.println("Error loading server musics: " + e.getMessage());
            return new ArrayList<>();
        }
    }

    public static void saveUsers(List<User> users) {
        try (Writer writer = new FileWriter(USERS_FILE)) {
            gson.toJson(users, writer);
        } catch (IOException e) {
            System.out.println("Error saving users: " + e.getMessage());
        }
    }

    public static List<User> loadUsers() {
        try (Reader reader = new FileReader(USERS_FILE)) {
            Type userListType = new TypeToken<List<User>>(){}.getType();
            List<User> users = gson.fromJson(reader, userListType);
            return users != null ? users : new ArrayList<>();
        } catch (FileNotFoundException e) {
            return new ArrayList<>();
        } catch (IOException e) {
            System.out.println("Error loading users: " + e.getMessage());
            return new ArrayList<>();
        }
    }
}
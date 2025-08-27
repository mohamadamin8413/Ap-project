import java.util.ArrayList;
import java.util.List;
import java.io.*;

public class PlayList {
    private static long lastId = loadLastId("playlist_last_id.txt");
    private long id;
    private String name;
    private String creatorEmail;
    private List<Music> musics;

    public PlayList(String name, String creatorEmail) {
        this.id = ++lastId;
        saveLastId("playlist_last_id.txt", lastId);
        this.name = name;
        this.creatorEmail = creatorEmail;
        this.musics = new ArrayList<>();
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

    public long getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getCreatorEmail() {
        return creatorEmail;
    }

    public List<Music> getMusics() {
        return new ArrayList<>(musics);
    }

    public boolean addMusic(Music music) {
        if (music != null && !musics.contains(music)) {
            musics.add(music);
            return true;
        }
        return false;
    }

    public boolean removeMusic(String musicName) {
        if (musicName != null) {
            for (int i = 0; i < musics.size(); i++) {
                if (musics.get(i).getTitle().equals(musicName)) {
                    musics.remove(i);
                    return true;
                }
            }
        }
        return false;
    }

    public boolean removeMusicById(long musicId) {
        for (int i = 0; i < musics.size(); i++) {
            if (musics.get(i).getId() == musicId) {
                musics.remove(i);
                return true;
            }
        }
        return false;
    }
}
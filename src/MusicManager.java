import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

public class MusicManager {
    private List<Music> serverMusics;
    private static final String MUSIC_DIR = System.getProperty("user.dir") + File.separator + "musics";
    private static final String DEFAULT_MUSICS_DIR = System.getProperty("user.dir") + File.separator + "default_musics";

    public MusicManager() {
        this.serverMusics = DatabaseManager.loadServerMusics();
    }

    public List<Music> getServerMusics() {
        return new ArrayList<>(serverMusics);
    }

    public Music findByName(String name) {
        for (Music music : serverMusics) {
            if (music.getTitle().equalsIgnoreCase(name)) {
                return music;
            }
        }
        return null;
    }

}
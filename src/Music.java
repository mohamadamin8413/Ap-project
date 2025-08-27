import java.io.*;
import java.util.concurrent.atomic.AtomicLong;

public class Music implements Serializable {
    private static long lastId = loadLastId("music_last_id.txt");
    private final long id;
    private final String title;
    private final String artist;
    private final String filePath;
    private final String uploaderEmail;
    private int likes;

    public Music(String title, String artist, String filePath, String uploaderEmail) {
        this.id = ++lastId;
        saveLastId("music_last_id.txt", lastId);
        String[] metadata = MusicUtils.extractMetaData(filePath);
        this.title = (metadata[0] != null && !metadata[0].trim().isEmpty()) ? metadata[0].trim() : title.trim();
        this.artist = (metadata[1] != null && !metadata[1].trim().isEmpty()) ? metadata[1].trim() : artist.trim();
        this.filePath = filePath;
        this.uploaderEmail = uploaderEmail != null ? uploaderEmail.trim() : "";
        this.likes = 0;
    }

    public void addLike() {
        this.likes++;
    }

    public void removeLike() {
        if (this.likes > 0) {
            this.likes--;
        }
    }

    public int getLikes() {
        return likes;
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
            System.out.println("No previous lastId found, starting from 0");
            return 0;
        } catch (IOException | NumberFormatException e) {
            System.err.println("Error loading last ID: " + e.getMessage());
            return 0;
        }
    }

    private static void saveLastId(String filename, long id) {
        try {
            File file = new File(filename);
            File parentDir = file.getParentFile();
            if (parentDir != null && !parentDir.exists()) {
                parentDir.mkdirs();
            }
            BufferedWriter writer = new BufferedWriter(new FileWriter(file));
            writer.write(String.valueOf(id));
            writer.close();
            System.out.println("Saved lastId: " + id);
        } catch (IOException e) {
            System.err.println("Error saving last ID: " + e.getMessage());
        }
    }

    public long getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public String getArtist() {
        return artist;
    }

    public String getFilePath() {
        return filePath;
    }

    public String getUploaderEmail() {
        return uploaderEmail;
    }
}
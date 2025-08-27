import com.mpatric.mp3agic.*;

public class MusicUtils {
    public static String[] extractMetaData(String filePath) {
        try {
            Mp3File mp3file = new Mp3File(filePath);
            if (mp3file.hasId3v2Tag()) {
                ID3v2 id3v2Tag = mp3file.getId3v2Tag();
                String title = id3v2Tag.getTitle();
                String artist = id3v2Tag.getArtist();
                return new String[] { title, artist };
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return new String[] { null, null };
    }
}
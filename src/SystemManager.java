import java.util.Scanner;
import java.util.List;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.Set;

public class SystemManager {
    private DatabaseManager db = new DatabaseManager();
    private MusicManager musicManager = new MusicManager();
    private UserManager userManager = new UserManager();

    public SystemManager() {
        userManager.setMusicManager(musicManager);
    }

    public static void showMenu() {
        System.out.println("1 Display user information");
        System.out.println("2 Display playlist information");
        System.out.println("3 Display music information");
        System.out.println("4 Display most liked music");
        System.out.println("5 Delete a user");
        System.out.println("6 Delete a song from a playlist");
        System.out.println("7 Display user's music");
        System.out.println("8 Delete a user's music");
        System.out.println("9 List server music");
        System.out.println("0 Exit");
    }

    private void displayUserInfo() {
        System.out.println("--- User Information ---");
        List<User> users = userManager.getUsers();
        if (users.isEmpty()) {
            System.out.println("No users found.");
        } else {
            for (int i = 0; i < users.size(); i++) {
                User user = users.get(i);
                System.out.println((i + 1) + ". Username: " + user.getUsername() + ", Email: " + user.getEmail() + ", Playlists: " + user.getPlaylists().size());
            }
        }
    }

    private void displayPlaylistInfo() {
        System.out.println("--- Playlist Information ---");
        List<User> users = userManager.getUsers();
        boolean hasPlaylists = false;
        for (User user : users) {
            List<PlayList> playlists = userManager.getUserPlaylists(user.getEmail());
            if (!playlists.isEmpty()) {
                hasPlaylists = true;
                System.out.println("User: " + user.getUsername() + " (" + user.getEmail() + ")");
                for (int i = 0; i < playlists.size(); i++) {
                    PlayList playlist = playlists.get(i);
                    System.out.println("  " + (i + 1) + ". Playlist: " + playlist.getName() + ", Songs: " + playlist.getMusics().size());
                }
            }
        }
        if (!hasPlaylists) {
            System.out.println("No playlists found.");
        }
    }

    private void displayMusicInfo() {
        System.out.println("--- Music Information ---");
        List<Music> musics = musicManager.getServerMusics();
        if (musics.isEmpty()) {
            System.out.println("No music found.");
        } else {
            for (int i = 0; i < musics.size(); i++) {
                Music music = musics.get(i);
                System.out.println((i + 1) + ". Title: " + music.getTitle() + ", Artist: " + music.getArtist() + ", Likes: " + music.getLikes() + ", ID: " + music.getId());
            }
        }
    }

    private void displayMostLikedMusic() {
        System.out.println("--- Most Liked Music ---");
        List<Music> musics = musicManager.getServerMusics();
        if (musics.isEmpty()) {
            System.out.println("No music found.");
            return;
        }
        List<Music> sortedMusics = new ArrayList<>(musics);
        sortedMusics.sort(Comparator.comparingInt(Music::getLikes).reversed());
        if (sortedMusics.get(0).getLikes() == 0) {
            System.out.println("No liked music found.");
        } else {
            for (int i = 0; i < sortedMusics.size(); i++) {
                Music music = sortedMusics.get(i);
                if (music.getLikes() > 0) {
                    System.out.println((i + 1) + ". Title: " + music.getTitle() + ", Artist: " + music.getArtist() + ", Likes: " + music.getLikes() + ", ID: " + music.getId());
                }
            }
        }
    }

    private void deleteUser(Scanner scanner) {
        System.out.println("--- Delete User ---");
        displayUserInfo();
        List<User> users = userManager.getUsers();
        if (users.isEmpty()) {
            return;
        }
        System.out.print("Enter the email of the user to delete: ");
        String email = scanner.nextLine().trim();
        if (userManager.deleteUser(email)) {
            System.out.println("User with email " + email + " deleted successfully.");
        } else {
            System.out.println("User with email " + email + " not found.");
        }
    }

    private void deleteSongFromPlaylist(Scanner scanner) {
        System.out.println("--- Delete Song from Playlist ---");
        displayUserInfo();
        List<User> users = userManager.getUsers();
        if (users.isEmpty()) {
            return;
        }
        System.out.print("Enter the email of the user: ");
        String email = scanner.nextLine().trim();
        User user = userManager.getUserByEmail(email);
        if (user == null) {
            System.out.println("User with email " + email + " not found.");
            return;
        }
        List<PlayList> playlists = userManager.getUserPlaylists(email);
        if (playlists.isEmpty()) {
            System.out.println("No playlists found for user " + email + ".");
            return;
        }
        System.out.println("Playlists for user " + user.getUsername() + " (" + email + "):");
        for (int i = 0; i < playlists.size(); i++) {
            System.out.println((i + 1) + ". " + playlists.get(i).getName() + ", Songs: " + playlists.get(i).getMusics().size());
        }
        System.out.print("Enter the name of the playlist: ");
        String playlistName = scanner.nextLine().trim();
        PlayList playlist = user.findPlaylistByName(playlistName);
        if (playlist == null) {
            System.out.println("Playlist " + playlistName + " not found.");
            return;
        }
        List<Music> songs = playlist.getMusics();
        if (songs.isEmpty()) {
            System.out.println("No songs found in playlist " + playlistName + ".");
            return;
        }
        System.out.println("Songs in playlist " + playlistName + ":");
        for (int i = 0; i < songs.size(); i++) {
            Music music = songs.get(i);
            System.out.println((i + 1) + ". Title: " + music.getTitle() + ", Artist: " + music.getArtist() + ", ID: " + music.getId());
        }
        System.out.print("Enter the ID of the song to delete: ");
        String input = scanner.nextLine().trim();
        try {
            long musicId = Long.parseLong(input);
            if (playlist.removeMusicById(musicId)) {
                userManager.removePlaylistFromUser(email, playlistName);
                userManager.addPlaylistToUser(email, playlist);
                System.out.println("Song with ID " + musicId + " removed from playlist " + playlistName + ".");
            } else {
                System.out.println("Song with ID " + musicId + " not found in playlist " + playlistName + ".");
            }
        } catch (NumberFormatException e) {
            System.out.println("Invalid ID format. Please enter a valid number.");
        }
    }

    private void displayUserMusic(Scanner scanner) {
        System.out.println("--- Display User's Music ---");
        displayUserInfo();
        List<User> users = userManager.getUsers();
        if (users.isEmpty()) {
            return;
        }
        System.out.print("Enter the email of the user: ");
        String email = scanner.nextLine().trim();
        User user = userManager.getUserByEmail(email);
        if (user == null) {
            System.out.println("User with email " + email + " not found.");
            return;
        }
        Set<Music> userMusic = new HashSet<>();
        userMusic.addAll(user.getLikedMusics());
        userMusic.addAll(user.getUserMusics());
        for (PlayList playlist : user.getPlaylists()) {
            userMusic.addAll(playlist.getMusics());
        }
        if (userMusic.isEmpty()) {
            System.out.println("No music found for user " + email + ".");
            return;
        }
        System.out.println("Music for user " + user.getUsername() + " (" + email + "):");
        int index = 1;
        for (Music music : userMusic) {
            System.out.println(index++ + ". Title: " + music.getTitle() + ", Artist: " + music.getArtist() + ", Likes: " + music.getLikes() + ", ID: " + music.getId());
        }
    }

    private void deleteUserMusic(Scanner scanner) {
        System.out.println("--- Delete User's Music ---");
        displayUserInfo();
        List<User> users = userManager.getUsers();
        if (users.isEmpty()) {
            return;
        }
        System.out.print("Enter the email of the user: ");
        String email = scanner.nextLine().trim();
        User user = userManager.getUserByEmail(email);
        if (user == null) {
            System.out.println("User with email " + email + " not found.");
            return;
        }
        Set<Music> userMusic = new HashSet<>();
        userMusic.addAll(user.getLikedMusics());
        userMusic.addAll(user.getUserMusics());
        for (PlayList playlist : user.getPlaylists()) {
            userMusic.addAll(playlist.getMusics());
        }
        if (userMusic.isEmpty()) {
            System.out.println("No music found for user " + email + ".");
            return;
        }
        System.out.println("Music for user " + user.getUsername() + " (" + email + "):");
        int index = 1;
        for (Music music : userMusic) {
            System.out.println(index++ + ". Title: " + music.getTitle() + ", Artist: " + music.getArtist() + ", ID: " + music.getId());
        }
        System.out.print("Enter the ID of the song to delete: ");
        String input = scanner.nextLine().trim();
        try {
            long musicId = Long.parseLong(input);
            Music music = userManager.findMusicById(musicId, user);
            if (music == null) {
                System.out.println("Song with ID " + musicId + " not found in user's music.");
                return;
            }
            boolean deleted = false;
            if (user.getLikedMusics().stream().anyMatch(m -> m.getId() == musicId)) {
                user.unlikeMusic(music.getTitle());
                music.removeLike();
                System.out.println("Song with ID " + musicId + " removed from liked music.");
                deleted = true;
            }
            if (user.getUserMusics().stream().anyMatch(m -> m.getId() == musicId)) {
                user.removeUserMusic(music.getTitle());
                System.out.println("Song with ID " + musicId + " removed from user's music library.");
                deleted = true;
            }
            for (PlayList playlist : user.getPlaylists()) {
                if (playlist.removeMusicById(musicId)) {
                    userManager.removePlaylistFromUser(email, playlist.getName());
                    userManager.addPlaylistToUser(email, playlist);
                    System.out.println("Song with ID " + musicId + " removed from playlist " + playlist.getName() + ".");
                    deleted = true;
                }
            }
            if (deleted) {
                DatabaseManager.saveUsers(userManager.getUsers());
            } else {
                System.out.println("Song with ID " + musicId + " not found in user's music.");
            }
        } catch (NumberFormatException e) {
            System.out.println("Invalid ID format. Please enter a valid number.");
        }
    }

    private void listServerMusic() {
        System.out.println("--- Server Music ---");
        List<Music> musics = musicManager.getServerMusics();
        if (musics.isEmpty()) {
            System.out.println("No music found on server.");
        } else {
            for (int i = 0; i < musics.size(); i++) {
                Music music = musics.get(i);
                System.out.println((i + 1) + ". Title: " + music.getTitle() + ", Artist: " + music.getArtist() + ", Likes: " + music.getLikes() + ", ID: " + music.getId());
            }
        }
    }

    public static void main(String[] args) {
        SystemManager systemManager = new SystemManager();
        Scanner scanner = new Scanner(System.in);
        int choice;
        do {
            showMenu();
            System.out.print("Enter your choice: ");
            while (!scanner.hasNextInt()) {
                System.out.println("Invalid input! Please enter a number.");
                System.out.print("Enter your choice: ");
                scanner.next();
            }
            choice = scanner.nextInt();
            scanner.nextLine();
            switch (choice) {
                case 1:
                    systemManager.displayUserInfo();
                    break;
                case 2:
                    systemManager.displayPlaylistInfo();
                    break;
                case 3:
                    systemManager.displayMusicInfo();
                    break;
                case 4:
                    systemManager.displayMostLikedMusic();
                    break;
                case 5:
                    systemManager.deleteUser(scanner);
                    break;
                case 6:
                    systemManager.deleteSongFromPlaylist(scanner);
                    break;
                case 7:
                    systemManager.displayUserMusic(scanner);
                    break;
                case 8:
                    systemManager.deleteUserMusic(scanner);
                    break;
                case 9:
                    systemManager.listServerMusic();
                    break;
                case 0:
                    System.out.println("Exiting Admin Panel...");
                    break;
                default:
                    System.out.println("Invalid choice! Please select a valid option.");
            }
            System.out.println();
        } while (choice != 0);
        scanner.close();
    }
}
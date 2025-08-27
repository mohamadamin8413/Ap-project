import java.io.*;
import java.net.Socket;

public class ClientHandeler implements Runnable {
    private final Socket clientSocket;
    private final RequestHandeler requestHandeler;

    public ClientHandeler(Socket clientSocket) {
        this.clientSocket = clientSocket;
        this.requestHandeler = new RequestHandeler();
    }

    @Override
    public void run() {
        try (
                BufferedReader in = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
                BufferedWriter out = new BufferedWriter(new OutputStreamWriter(clientSocket.getOutputStream()))
        ) {
            String requestLine;
            while ((requestLine = in.readLine()) != null) {
                String response = requestHandeler.processRequest(requestLine);
                out.write(response);
                out.newLine();
                out.flush();
            }
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            try {
                clientSocket.close();
                System.out.println("Client disconnected: " + clientSocket.getInetAddress());
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }
}
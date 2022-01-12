import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.stream.Stream;
import java.lang.Thread;
 
public class EatResources {
    //Read file content into the string with - Files.lines(Path path, Charset cs)
    private static String ReadFile(String path) {
        StringBuilder contentBuilder = new StringBuilder();
 
        try (Stream<String> stream = Files.lines( Paths.get(path), StandardCharsets.UTF_8)) {
            stream.forEach(s->contentBuilder.append(s).append("\n"));
        } catch (IOException e) {
            //e.printStackTrace();
            return null;
        }
 
        return contentBuilder.toString();
    }

    private static int ReadIntFile(String path) {
      String data = ReadFile(path);
      try {
        data = data.replace("\n", "");
        return Integer.valueOf(data);
      } catch (Exception e) {
          return 0;
      }
    }

    public static void main(String[] args) throws InterruptedException {
        int mem_usage = 0;
        String path = "/tmp/eat-mem.txt";
        int[] mem_user;

        if (args.length > 0) {
          path = args[0];
          System.out.println("Watching file: "+path);
        }

        while (true) {
          int new_mem_usage = ReadIntFile(path);
          if (mem_usage != new_mem_usage) {
            System.out.println(new_mem_usage);
            mem_usage = new_mem_usage;
            // size in Mb, 32-bit ints (4 bytes)
            int int_count = mem_usage*1000000/4;
            mem_user = new int[int_count];
          }
          Thread.sleep(1000);
        }
    }
 
}

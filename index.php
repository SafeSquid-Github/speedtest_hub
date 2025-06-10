<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Speed Test Hub</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: #f0f2f5;
            color: #333;
            margin: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            text-align: center;
        }
        .container {
            background-color: #ffffff;
            padding: 40px;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
        }
        h1 {
            font-size: 2.5em;
            margin-bottom: 30px;
            color: #1a202c;
        }
        .app-grid {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            justify-content: center;
        }
        .app-tile {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            width: 150px;
            height: 150px;
            padding: 20px;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            text-decoration: none;
            color: #4a5568;
            background-color: #f7fafc;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        .app-tile:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
            border-color: #cbd5e0;
        }
        .app-tile img {
            width: 48px;
            height: 48px;
            margin-bottom: 15px;
        }
        .app-tile span {
            font-size: 1.1em;
            font-weight: 600;
        }
        .no-apps {
            color: #718096;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Select a Speed Test</h1>
        <div class="app-grid">
            <?php
                // The directory to scan (current directory)
                $scan_dir = __DIR__;
                
                // A default SVG icon to use if a favicon isn't found
                $default_favicon_svg = 'data:image/svg+xml;base64,'.base64_encode('<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 017.843 4.582M12 3a8.997 8.997 0 00-7.843 4.582m15.686 0A11.953 11.953 0 0112 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0121 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0112 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 013 12c0-1.605.42-3.113 1.157-4.418" /></svg>');

                $apps_found = false;

                // Scan for directories
                $items = scandir($scan_dir);
                foreach ($items as $item) {
                    $item_path = $scan_dir . '/' . $item;
                    // Check if it's a directory, not '.', '..', and contains an index.html
                    if (is_dir($item_path) && $item != '.' && $item != '..' && file_exists($item_path . '/index.html')) {
                        $apps_found = true;
                        $app_name = htmlspecialchars($item);
                        $app_title = ucwords(str_replace(['-', '_'], ' ', $app_name));
                        $favicon_path = $item_path . '/favicon.ico';
                        
                        // Use the app's favicon if it exists, otherwise use the default SVG
                        $icon_src = file_exists($favicon_path) ? ($app_name . '/favicon.ico') : $default_favicon_svg;

                        echo "<a href='{$app_name}/' class='app-tile'>";
                        echo "<img src='{$icon_src}' alt='{$app_title} icon'>";
                        echo "<span>{$app_title}</span>";
                        echo "</a>";
                    }
                }

                if (!$apps_found) {
                    echo "<p class='no-apps'>No speed test applications found in the web root.</p>";
                }
            ?>
        </div>
    </div>
</body>
</html>
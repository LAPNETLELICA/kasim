import '../models/allowed_service.dart';

class AllowedServicesRepository {
  static List<AllowedService> getAllServices() {
    return [
      // Search Engines
      AllowedService(
        id: 'google-search',
        name: 'Google Search',
        category: 'Search Engines',
        hosts: ['google.com', 'www.google.com'],
        iconAsset: 'assets/icons/google.png',
      ),
      AllowedService(
        id: 'bing',
        name: 'Bing',
        category: 'Search Engines',
        hosts: ['bing.com', 'www.bing.com'],
        iconAsset: 'assets/icons/bing.png',
      ),
      AllowedService(
        id: 'yahoo-search',
        name: 'Yahoo Search',
        category: 'Search Engines',
        hosts: ['search.yahoo.com'],
        iconAsset: 'assets/icons/yahoo.png',
      ),
      AllowedService(
        id: 'duckduckgo',
        name: 'DuckDuckGo',
        category: 'Search Engines',
        hosts: ['duckduckgo.com'],
        iconAsset: 'assets/icons/duckduckgo.png',
      ),
      AllowedService(
        id: 'ecosia',
        name: 'Ecosia',
        category: 'Search Engines',
        hosts: ['ecosia.org'],
        iconAsset: 'assets/icons/ecosia.png',
      ),
      AllowedService(
        id: 'yandex',
        name: 'Yandex',
        category: 'Search Engines',
        hosts: ['yandex.com'],
        iconAsset: 'assets/icons/yandex.png',
      ),
      AllowedService(
        id: 'baidu',
        name: 'Baidu',
        category: 'Search Engines',
        hosts: ['baidu.com'],
        iconAsset: 'assets/icons/baidu.png',
      ),
      AllowedService(
        id: 'qwant',
        name: 'Qwant',
        category: 'Search Engines',
        hosts: ['qwant.com'],
        iconAsset: 'assets/icons/qwant.png',
      ),
      AllowedService(
        id: 'startpage',
        name: 'Startpage',
        category: 'Search Engines',
        hosts: ['startpage.com'],
        iconAsset: 'assets/icons/startpage.png',
      ),
      AllowedService(
        id: 'brave-search',
        name: 'Brave Search',
        category: 'Search Engines',
        hosts: ['search.brave.com'],
        iconAsset: 'assets/icons/brave.png',
      ),

      // AI Tools
      AllowedService(
        id: 'google-gemini',
        name: 'Google Gemini',
        category: 'AI Tools',
        hosts: ['gemini.google.com', 'generativelanguage.googleapis.com'],
        iconAsset: 'assets/icons/gemini.png',
      ),
      AllowedService(
        id: 'chatgpt',
        name: 'ChatGPT',
        category: 'AI Tools',
        hosts: ['chatgpt.com', 'openai.com'],
        iconAsset: 'assets/icons/chatgpt.png',
      ),
      AllowedService(
        id: 'microsoft-copilot',
        name: 'Microsoft Copilot',
        category: 'AI Tools',
        hosts: ['copilot.microsoft.com'],
        iconAsset: 'assets/icons/copilot.png',
      ),
      AllowedService(
        id: 'claude',
        name: 'Claude (Anthropic)',
        category: 'AI Tools',
        hosts: ['claude.ai'],
        iconAsset: 'assets/icons/claude.png',
      ),
      AllowedService(
        id: 'perplexity-ai',
        name: 'Perplexity AI',
        category: 'AI Tools',
        hosts: ['perplexity.ai'],
        iconAsset: 'assets/icons/perplexity.png',
      ),
      AllowedService(
        id: 'meta-ai',
        name: 'Meta AI',
        category: 'AI Tools',
        hosts: ['meta.ai'],
        iconAsset: 'assets/icons/meta.png',
      ),

      // Reference & Academic
      AllowedService(
        id: 'wikipedia',
        name: 'Wikipedia',
        category: 'Reference & Academic',
        hosts: ['wikipedia.org', '*.wikipedia.org'],
        iconAsset: 'assets/icons/wikipedia.png',
      ),
      AllowedService(
        id: 'google-scholar',
        name: 'Google Scholar',
        category: 'Reference & Academic',
        hosts: ['scholar.google.com'],
        iconAsset: 'assets/icons/scholar.png',
      ),
      AllowedService(
        id: 'researchgate',
        name: 'ResearchGate',
        category: 'Reference & Academic',
        hosts: ['researchgate.net'],
        iconAsset: 'assets/icons/researchgate.png',
      ),
      AllowedService(
        id: 'academia-edu',
        name: 'Academia.edu',
        category: 'Reference & Academic',
        hosts: ['academia.edu'],
        iconAsset: 'assets/icons/academia.png',
      ),
      AllowedService(
        id: 'semantic-scholar',
        name: 'Semantic Scholar',
        category: 'Reference & Academic',
        hosts: ['semanticscholar.org'],
        iconAsset: 'assets/icons/semanticscholar.png',
      ),

      // Educational Platforms
      AllowedService(
        id: 'coursera',
        name: 'Coursera',
        category: 'Educational Platforms',
        hosts: ['coursera.org'],
        iconAsset: 'assets/icons/coursera.png',
      ),
      AllowedService(
        id: 'khan-academy',
        name: 'Khan Academy',
        category: 'Educational Platforms',
        hosts: ['khanacademy.org'],
        iconAsset: 'assets/icons/khan.png',
      ),
      AllowedService(
        id: 'edx',
        name: 'edX',
        category: 'Educational Platforms',
        hosts: ['edx.org'],
        iconAsset: 'assets/icons/edx.png',
      ),
      AllowedService(
        id: 'alx-africa',
        name: 'ALX Africa',
        category: 'Educational Platforms',
        hosts: ['alxafrica.com'],
        iconAsset: 'assets/icons/alx.png',
      ),
      AllowedService(
        id: 'andela',
        name: 'Andela',
        category: 'Educational Platforms',
        hosts: ['andela.com'],
        iconAsset: 'assets/icons/andela.png',
      ),
      AllowedService(
        id: 'atingi',
        name: 'atingi',
        category: 'Educational Platforms',
        hosts: ['atingi.org'],
        iconAsset: 'assets/icons/atingi.png',
      ),

      // Cloud Storage / File Access
      AllowedService(
        id: 'google-drive',
        name: 'Google Drive',
        category: 'Cloud Storage / File Access',
        hosts: ['drive.google.com'],
        iconAsset: 'assets/icons/drive.png',
      ),
      AllowedService(
        id: 'onedrive',
        name: 'OneDrive',
        category: 'Cloud Storage / File Access',
        hosts: ['onedrive.live.com'],
        iconAsset: 'assets/icons/onedrive.png',
      ),
      AllowedService(
        id: 'dropbox',
        name: 'Dropbox',
        category: 'Cloud Storage / File Access',
        hosts: ['dropbox.com'],
        iconAsset: 'assets/icons/dropbox.png',
      ),

      // Communication
      AllowedService(
        id: 'gmail',
        name: 'Gmail',
        category: 'Communication',
        hosts: ['mail.google.com'],
        iconAsset: 'assets/icons/gmail.png',
      ),
      AllowedService(
        id: 'outlook',
        name: 'Outlook',
        category: 'Communication',
        hosts: ['outlook.live.com'],
        iconAsset: 'assets/icons/outlook.png',
      ),
    ];
  }
}
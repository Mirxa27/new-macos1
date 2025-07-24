declare module '@google/genai' {
  export const GoogleGenAI: any;
  export interface LiveServerMessage {
    [key: string]: any;
  }
  export const MediaResolution: any;
  export const Modality: any;
  export interface Session {
    sendClientContent(content: any): void;
    close(): void;
  }
}

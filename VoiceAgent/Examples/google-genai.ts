export interface LiveServerMessage {
  serverContent?: {
    turnComplete?: boolean;
    modelTurn?: { parts?: any[] };
  };
}

export enum MediaResolution { MEDIA_RESOLUTION_MEDIUM = 'MEDIUM' }
export enum Modality { AUDIO = 'AUDIO' }

export class Session {
  constructor(private callbacks?: any) {}
  sendClientContent(_content: any): void {
    console.log('sendClientContent called with', _content);
    this.callbacks?.onmessage?.({
      serverContent: {
        modelTurn: { parts: [{ text: '(mock response)' }] },
        turnComplete: true,
      },
    });
  }
  close(): void {
    console.log('session closed');
    this.callbacks?.onclose?.({ reason: 'mock close' });
  }
}

export class GoogleGenAI {
  constructor(_opts: any) {}
  live = {
    async connect({ callbacks }: { callbacks?: any; model?: string; config?: any; }): Promise<Session> {
      callbacks?.onopen?.();
      return new Session(callbacks);
    },
  };
}

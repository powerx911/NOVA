import { Component, type ErrorInfo, type ReactNode } from 'react';

type Props = { children: ReactNode };
type State = { hasError: boolean };

export class AppErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false };

  static getDerivedStateFromError(): State {
    return { hasError: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    // Keep the fallback independent of diagnostics/network services.
    console.error('Unexpected application render error', error, info.componentStack);
  }

  render() {
    if (this.state.hasError) {
      return (
        <main className="min-h-screen bg-[#0B0D12] text-[#F4F5F7] flex items-center justify-center p-6">
          <section className="w-full max-w-md rounded-2xl border border-amber-500/25 bg-[#141821] p-6 space-y-4 text-center">
            <div className="mx-auto h-12 w-12 rounded-full bg-amber-500/10 flex items-center justify-center text-amber-300 text-xl">!</div>
            <h1 className="text-lg font-bold">حدث خطأ غير متوقع</h1>
            <p className="text-sm leading-7 text-[#AAB1BE]">
              تعذّر عرض هذه الصفحة. أعد تحميل اللعبة للمحاولة من جديد.
            </p>
            <button
              type="button"
              onClick={() => window.location.reload()}
              className="w-full min-h-[46px] rounded-xl bg-[#B91C32] hover:bg-[#E04455] text-white text-sm font-semibold"
            >
              إعادة تحميل اللعبة
            </button>
          </section>
        </main>
      );
    }

    return this.props.children;
  }
}

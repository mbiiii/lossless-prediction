export const metadata = {
  title: "Lossless Prediction Market",
  description: "No-loss vToken price prediction. Principal safe, yield is the prize.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}

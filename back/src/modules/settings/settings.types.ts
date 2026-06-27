/** Shape do arquivo multipart (memoryStorage do multer). Local p/ não acoplar ao OS. */
export interface UploadedImage {
  buffer: Buffer;
  mimetype: string;
  size: number;
  originalname: string;
}

import { Product } from "./Product";
import { ProductId } from "./ProductId";
import { ProductName } from "./ProductName";

export abstract class ProductRepository {
	abstract save(product: Product): Promise<void>;
	abstract searchById(id: ProductId): Promise<Product | null>;
	abstract searchAll(): Promise<Product[]>;
	abstract searchByName(name: ProductName): Promise<Product | null>;
}

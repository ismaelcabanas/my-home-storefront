import { Service } from "diod";
import { Row } from "postgres";

import { PostgresRepository } from "../../../shared/infrastructure/postgres/PostgresRepository";
import { Cursor } from "../domain/Cursor";
import { InventoryItem } from "../domain/InventoryItem";
import { InventoryItemNotFoundError } from "../domain/InventoryItemNotFoundError";
import { InventoryItemRepository } from "../domain/InventoryItemRepository";
import {
	createPaginatedInventoryItems,
	emptyPaginatedInventoryItems,
	type PaginatedInventoryItems,
} from "../domain/PaginatedInventoryItems";

@Service()
export class PostgresInventoryItemRepository
	extends PostgresRepository<InventoryItem>
	implements InventoryItemRepository
{
	async save(item: InventoryItem): Promise<void> {
		const primitives = item.toPrimitives();

		await this.execute`
			INSERT INTO inventory.inventory_items (id, name, state, requires_purchase, created_at)
			VALUES (
				${primitives.id},
				${primitives.name},
				${primitives.state},
				${primitives.requiresPurchase},
				${primitives.createdAt}
			)
			ON CONFLICT (id) DO UPDATE SET
				state = EXCLUDED.state,
				requires_purchase = EXCLUDED.requires_purchase
		`;
	}

	async searchById(id: string): Promise<InventoryItem | null> {
		return await this
			.searchOne`SELECT * FROM inventory.inventory_items WHERE id = ${id}`;
	}

	async findById(id: string): Promise<InventoryItem> {
		const item = await this.searchById(id);
		if (item === null) {
			throw new InventoryItemNotFoundError(id);
		}

		return item;
	}

	async searchAll(
		limit: number,
		cursor: string | null,
	): Promise<PaginatedInventoryItems> {
		// Input Validation: Validate limit between 1-100, default to 20
		const validatedLimit =
			typeof limit === "number" && limit >= 1 && limit <= 100
				? limit
				: 20;

		// Fetch limit + 1 items to determine if more pages exist
		const fetchLimit = validatedLimit + 1;

		let items: InventoryItem[];

		if (cursor === null || cursor === "") {
			// No cursor: Start from beginning, no WHERE filter
			items = await this.searchMany`
				SELECT * FROM inventory.inventory_items
				ORDER BY name ASC, created_at ASC
				LIMIT ${fetchLimit}
			`;
		} else {
			// Decode cursor using Cursor.decode()
			const decodedCursor = Cursor.decode(cursor);

			// Filter WHERE name > cursor.name OR (name = cursor.name AND created_at > cursor.createdAt)
			items = await this.searchMany`
				SELECT * FROM inventory.inventory_items
				WHERE name > ${decodedCursor.name}
					OR (name = ${decodedCursor.name} AND created_at > ${decodedCursor.createdAt})
				ORDER BY name ASC, created_at ASC
				LIMIT ${fetchLimit}
			`;
		}

		// Edge Case: Empty result set
		if (items.length === 0) {
			return emptyPaginatedInventoryItems();
		}

		// If returned items > limit: Remove last item, set nextCursor from that item, hasMore = true
		if (items.length > validatedLimit) {
			const lastItem = items[validatedLimit];
			const pageItems = items.slice(0, validatedLimit);
			const nextCursor = new Cursor(
				lastItem.name.value,
				lastItem.createdAt,
			).encode();

			return createPaginatedInventoryItems(
				pageItems.map((item) => item.toPrimitives()),
				nextCursor,
				true,
			);
		}

		// If returned items <= limit: Set nextCursor = null, hasMore = false
		return createPaginatedInventoryItems(
			items.map((item) => item.toPrimitives()),
			null,
			false,
		);
	}

	async searchByRequiresPurchase(
		limit: number,
		cursor: string | null,
	): Promise<PaginatedInventoryItems> {
		// Input Validation: Validate limit between 1-100, default to 20
		const validatedLimit =
			typeof limit === "number" && limit >= 1 && limit <= 100
				? limit
				: 20;

		// Fetch limit + 1 items to determine if more pages exist
		const fetchLimit = validatedLimit + 1;

		let items: InventoryItem[];

		if (cursor === null || cursor === "") {
			// No cursor: Start from beginning with WHERE requires_purchase = true filter
			items = await this.searchMany`
				SELECT * FROM inventory.inventory_items
				WHERE requires_purchase = true
				ORDER BY name ASC, created_at ASC
				LIMIT ${fetchLimit}
			`;
		} else {
			// Decode cursor using Cursor.decode()
			const decodedCursor = Cursor.decode(cursor);

			// Filter WHERE requires_purchase = true AND (name > cursor.name OR (name = cursor.name AND created_at > cursor.createdAt))
			items = await this.searchMany`
				SELECT * FROM inventory.inventory_items
				WHERE requires_purchase = true
				  AND (name > ${decodedCursor.name} OR (name = ${decodedCursor.name} AND created_at > ${decodedCursor.createdAt}))
				ORDER BY name ASC, created_at ASC
				LIMIT ${fetchLimit}
			`;
		}

		// Edge Case: Empty result set
		if (items.length === 0) {
			return emptyPaginatedInventoryItems();
		}

		// If returned items > limit: Remove last item, set nextCursor from that item, hasMore = true
		if (items.length > validatedLimit) {
			const lastItem = items[validatedLimit];
			const pageItems = items.slice(0, validatedLimit);
			const nextCursor = new Cursor(
				lastItem.name.value,
				lastItem.createdAt,
			).encode();

			return createPaginatedInventoryItems(
				pageItems.map((item) => item.toPrimitives()),
				nextCursor,
				true,
			);
		}

		// If returned items <= limit: Set nextCursor = null, hasMore = false
		return createPaginatedInventoryItems(
			items.map((item) => item.toPrimitives()),
			null,
			false,
		);
	}

	protected toAggregate(row: Row): InventoryItem {
		return InventoryItem.fromPrimitives({
			id: row.id as string,
			name: row.name as string,
			state: row.state as string,
			requiresPurchase: row.requires_purchase as boolean,
			createdAt: row.created_at as string,
		});
	}
}
